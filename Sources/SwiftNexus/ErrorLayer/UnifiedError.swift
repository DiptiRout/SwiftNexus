//
//  UnifiedError.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 20/02/25.
//

import Foundation

public struct UnifiedError: Error, Sendable {
    public enum Category: String, Sendable, CaseIterable {
        case network
        case file
        case server
        case client
        case validation
        case security
        case decoding
        case middleware
        case retry
        case unknown
    }

    public let id = UUID()
    public let category: Category
    public let code: String
    public let userMessage: String
    public let technicalMessage: String
    public let underlyingError: Error?
    public let location: (file: String, line: Int)?
    public let context: AdditionalData
    public var recoveryActions: [RecoveryAction]
    public let timestamp: Date
    
    public init(
        category: Category,
        code: String,
        userMessage: String,
        technicalMessage: String,
        underlyingError: Error? = nil,
        location: (file: String, line: Int)? = nil,
        context: AdditionalData = .init(),
        recoveryActions: [RecoveryAction] = [],
        timestamp: Date = Date()
    ) {
        self.category = category
        self.code = code
        self.userMessage = userMessage
        self.technicalMessage = technicalMessage
        self.underlyingError = underlyingError
        self.location = location
        self.context = context
        self.recoveryActions = recoveryActions
        self.timestamp = timestamp
    }
}

// MARK: - Common Error Builders
public extension UnifiedError {
    static func generic(
        error: Error,
        file: String = #fileID,
        line: Int = #line
    ) -> Self {
        UnifiedError(
            category: .unknown,
            code: "UNKNOWN_ERROR",
            userMessage: "Something went wrong",
            technicalMessage: "Unexpected error: \(String(reflecting: error))",
            underlyingError: error,
            location: (file, line)
        )
    }
    
    static func validation(
        code: String,
        message: String,
        context: AdditionalData = .init()
    ) -> Self {
        UnifiedError(
            category: .validation,
            code: code,
            userMessage: message,
            technicalMessage: message,
            context: context
        )
    }
    
    static func network(
        code: String,
        message: String,
        underlyingError: Error? = nil,
        context: AdditionalData = .init()
    ) -> Self {
        UnifiedError(
            category: .network,
            code: code,
            userMessage: message,
            technicalMessage: underlyingError?.localizedDescription ?? message,
            underlyingError: underlyingError,
            context: context
        )
    }
}

// MARK: - Presentation Ready Extensions
public extension UnifiedError {
    var alertTitle: String {
        // Would use localized strings in production
        switch category {
        case .validation: return "Validation Error"
        case .network: return "Connection Error"
        default: return "Error"
        }
    }
    
    var alertMessage: String { userMessage }
}
