//
//  StoreService.swift
//  Pods
//
//  Created by admin on 2025/5/27.
//

import Foundation
import StoreKit
import BBKit

public class StoreService {
    private var productIds: [String] = []
    
    public static let shared = StoreService()
    
    public func start(productIds: [String], comple: @escaping (Transaction?) -> Void) {
        self.productIds = productIds
        updateTransactionsOnLaunch(comple: comple)
    }
    
    public func getProducts(productIds: [String] = []) async -> [Product] {
        var productIds = productIds
        if productIds.isEmpty {
            productIds = self.productIds
        }
        do {
            return try await Product.products(for: productIds)
        } catch {
            BBLog_e("获取商品失败 \(error)")
        }
        return []
    }
    
    public func restorePurchases() async throws -> Transaction? {
        let transactions = try await getValidProductTransations()
        var valids: [Transaction] = []
        transactions.forEach {
            let bool = $0.isValid
            if bool {
                valids.append($0)
            }
        }
        return valids.first
    }
    
    @discardableResult
    open func purchase(
        _ product: Product
    ) async -> Transaction? {
        do {
            let result = try await purchase(product, options: [])
            return result.1
        } catch {
            BBLog_e("订阅失败 = \(error.localizedDescription)")
            return nil
        }
    }
    
    @discardableResult
    open func purchase(
        _ product: Product,
        options: Set<Product.PurchaseOption>
    ) async throws -> (Product.PurchaseResult, Transaction?) {
        #if os(visionOS)
        throw StoreServiceError.unsupportedPlatform("This purchase operation is not supported in visionOS: Use @Environment(\\.purchase) instead.")
        #else
        
        let result = try await product.purchase()
        var trans: Transaction?
        switch result {
        case .success(let result):
            BBLog_i("支付成功")
            trans = try await finalizePurchaseResult(result)
        case .pending:
            BBLog_i("支付pending")
        case .userCancelled:
            BBLog_i("取消支付")
        @unknown default: break
        }
        return (result, trans)
        #endif
    }
    
    open func finalizePurchaseResult(
        _ result: VerificationResult<Transaction>
    ) async throws -> Transaction {
        let transaction = try result.verify()
        await transaction.finish()
        return transaction
    }
    
    open func checkCurrentEntitlements(comple: @escaping ([Transaction]) -> Void) {
        Task.detached {
            var isvailds: Set<Transaction> = []
            for await result in Transaction.currentEntitlements {
                let transac = try? result.verify()
                guard let transac else {
                    continue
                }
                let isvaild = transac.isValid
                isvailds.insert(transac)
            }
            
            comple(Array(isvailds))
        }
    }
    
    open func updateTransactionsOnLaunch(comple: @escaping (Transaction?) -> Void) {
        Task.detached {
            var isvailds: Set<Transaction> = []
    
            for await result in Transaction.updates {
                do {
                    let transac = try result.verify()
                    let isvaild = transac.isValid
                    
                    if isvaild {
                        isvailds.insert(transac)
                    }
                } catch {
                    BBLog_e("Transaction listener error: \(error)")
                }
            }
            
            let update = isvailds.first
            comple(update)
        }
    }
    
    open func getValidProductTransations() async throws -> [Transaction] {
        var transactions: [Transaction] = []
        for id in productIds {
            if let transaction = try await getValidTransaction(for: id) {
                transactions.append(transaction)
            }
        }
        return transactions
    }
    
    open func getValidTransaction(
        for productId: String
    ) async throws -> Transaction? {
        guard let latest = await Transaction.latest(for: productId) else { return nil }
        let result = try latest.verify()
        return result.isValid ? result : nil
    }
}

private extension VerificationResult where SignedType == Transaction {

    @discardableResult
    func verify() throws -> Transaction {
        switch self {
        case .unverified(let transaction, let error): throw StoreServiceError.invalidTransaction(transaction, error)
        case .verified(let transaction): return transaction
        }
    }
}

public extension Transaction {

    /// Whether or not the transaction is valid.
    ///
    /// A valid transaction has no revocation date, and also
    /// has no expiration date that has passed.
    var isValid: Bool {
        if revocationDate != nil { return false }
        guard let date = expirationDate else { return true }
        return date > Date()
    }
}

public enum StoreProductType: Equatable {
    case monthly      // 包月
    case quarterly    // 包季
    case yearly       // 包年
    case otherSubscription // 其他订阅周期
    case lifetime     // 一次性买断，可恢复（non-consumable）
    case nonRenewable // 非自动续订型（如固定期 VIP）
    case consumable   // 消耗型，不可恢复
    case unknown
}

public extension Product {
    var productType: StoreProductType {
        switch self.type {
        case .autoRenewable:
            if let period = subscription?.subscriptionPeriod {
                switch period.unit {
                case .month:
                    switch period.value {
                    case 1: return .monthly
                    case 3: return .quarterly
                    default: return .otherSubscription
                    }
                case .year:
                    return period.value == 1 ? .yearly : .otherSubscription
                default:
                    return .otherSubscription
                }
            }
            return .unknown

        case .nonConsumable:
            return .lifetime

        case .nonRenewable:
            return .nonRenewable

        case .consumable:
            return .consumable

        default:
            return .unknown
        }
    }

    /// 是否可以通过「恢复购买」找回
    var isRestorable: Bool {
        switch self.productType {
        case .lifetime, .nonRenewable, .monthly, .quarterly, .yearly, .otherSubscription:
            return true
        default:
            return false
        }
    }
    
    private static let priceFormatter: NumberFormatter = {
        let priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .currency
        return priceFormatter
    }()

    /// 本地化格式化价格字符串，使用商品的 priceFormatStyle.locale
     var localizedPrice: String? {
         let formatter = Product.priceFormatter
         // 使用 Product 的 locale（priceFormatStyle.locale）
         formatter.locale = priceFormatStyle.locale
         formatter.currencyCode = priceFormatStyle.currencyCode
         return formatter.string(from: price as NSDecimalNumber)
     }

    /// 获取商品价格对应的货币符号（如 "$", "¥"）
    var currencySymbol: String? {
        let formatter = Product.priceFormatter
        formatter.locale = priceFormatStyle.locale
        formatter.currencyCode = priceFormatStyle.currencyCode
        return formatter.currencySymbol
    }
    
    
    /// 价格数字字符串，保留两位小数，不带货币符号
    var priceNumberTwoDecimals: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        
        return formatter.string(from: self.price as NSDecimalNumber) ?? "\(self.price)"
    }
}
