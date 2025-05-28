//
//  StoreServiceError.swift
//  StoreKitHelper
//
//  Created by admin on 2025/5/28.
//

import Foundation

import StoreKit

/// This enum defines store service-speific errors.
public enum StoreServiceError: Error {
    
    /// This error is thrown if a transaction can't be verified.
    case invalidTransaction(Transaction, VerificationResult<Transaction>.VerificationError)
    
    /// This error is thrown if the platform doesn't support a purchase.
    case unsupportedPlatform(_ message: String)
}
