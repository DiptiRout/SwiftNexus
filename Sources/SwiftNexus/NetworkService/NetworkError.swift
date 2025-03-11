//
//  NetworkError.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// A comprehensive network error type with concurrency safety
/// - Generic Parameter:
///   - ErrorType: Domain-specific error model for client errors (4xx responses)
///
/// ## Error Categories
/// | Case                                                        | Typical Trigger                               |
/// |------------------------------------------------------|----------------------------------------------|
/// | `.requestConstructionFailed` | Invalid URL or query parameters
/// | `.networkFailure`                         | Connectivity issues
/// | `.serverError`                                | 5xx status code responses
/// | `.clientError`                                | 4xx status code with error model
/// | `.decodingFailure`                       | Response parsing failures
/// | `.cacheFailure`                             | Caching subsystem errors
/// | `.retryLimitExceeded`                | Failed after max retry attempts
/// | `.middlewareRejection`             | Request blocked by middleware
///
/// - Important: Conforms to `Sendable` for safe cross-actor use
public enum NetworkError<ErrorType: Error>: Error, Sendable {
    /// Failed to construct valid URLRequest
    /// - Example: Invalid URL components or malformed query parameters
    case requestConstructionFailed(URLError)
    
    /// Network layer failure (connectivity, TLS errors, etc)
    /// - Example: No internet connection, DNS resolution failed
    case networkFailure(URLError)
    
    /// Server-side error (500-599 HTTP status codes)
    /// - Contains raw response data for debugging
    case serverError(statusCode: Int, data: Data)
    
    /// Client error (400-499 HTTP status codes)
    /// - Contains parsed error model from response
    case clientError(statusCode: Int, errorModel: ErrorType)
    
    /// Response data decoding failure
    /// - Example: JSON parsing error, missing required fields
    case decodingFailure(Error)
    
    /// Cache read/write operation failure
    case fileError(Error)
    
    /// Maximum retry attempts exhausted
    case retryLimitExceeded
    
    /// Request rejected by middleware
    case middlewareRejection(reason: any MiddlewareRejectionReason)
    
    case invalidResponseConversion(
            expected: String,
            actual: String,
            context: [String: String]
        )
}

/// Protocol for type-safe middleware rejection reasons
/// - Conforms to `Sendable` and `Hashable` for concurrency safety
/// - Required: Human-readable description
///
/// ## Example
/// ```swift
/// enum AuthRejection: MiddlewareRejectionReason {
///     case invalidToken, expiredCredentials
///
///     var description: String {
///         switch self {
///         case .invalidToken: return "Invalid authentication token"
///         case .expiredCredentials: return "Credentials expired"
///         }
///     }
/// }
/// ```
public protocol MiddlewareRejectionReason: Sendable, Hashable {
    var description: String { get }
}

public enum FileError: Error {
    case fileExists
    case checksumMismatch
    case invalidDirectoryStructure
    case invalidTemporaryFile // New case
    case moveFailed(Error)
    case copyFailed(Error)
    case securityScopeViolation
}
