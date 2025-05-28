//
//  StoreService.swift
//  Pods
//
//  Created by admin on 2025/5/27.
//

import Foundation
import StoreKit

public class StoreService {
    private let productIds: [String]

    public init(
        productIds: [String]
    ) {
        self.productIds = productIds
        updateTransactionsOnLaunch()
    }
    
    public func getProducts(productIds: [String] = []) async throws -> [Product] {
        var productIds = productIds
        if productIds.isEmpty {
            productIds = self.productIds
        }
        return try await Product.products(for: productIds)
    }
    
    public func restorePurchases() async throws {
        let transactions = try await getValidProductTransations()
        var valids: [Transaction] = []
        transactions.forEach {
            let bool = $0.isValid
            if bool {
                valids.append($0)
            }
        }
        print(valids)
    }
    
    @discardableResult
    open func purchase(
        _ product: Product
    ) async throws -> (Product.PurchaseResult, Transaction?) {
        try await purchase(product, options: [])
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
        switch result {
        case .success(let result): try await finalizePurchaseResult(result)
        case .pending: break
        case .userCancelled: break
        @unknown default: break
        }
        return (result, nil)
        #endif
    }
    
    open func finalizePurchaseResult(
        _ result: VerificationResult<Transaction>
    ) async throws {
        let transaction = try result.verify()
        await transaction.finish()
    }
    
    open func updateTransactionsOnLaunch() {
        Task.detached {
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    continue
                }
                try result.verify()
                let isvaild = try result.verify().isValid
                print("res")
            }
            
            for await result in Transaction.updates {
                do {
                    try result.verify()
                    let isvaild = try result.verify().isValid
                    print("res")
                } catch {
                    print("Transaction listener error: \(error)")
                }
            }
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
