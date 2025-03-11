//
//  RetryPolicy.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// A concurrency-safe configuration for network request retry behavior
/// - Implements common backoff strategies with thread safety
/// - Conforms to `Sendable` for Swift 6 concurrency compliance
///
/// ## Example Usage
/// ```swift
/// // Standard retry policy with exponential backoff
/// let defaultPolicy = RetryPolicy(
///     maxAttempts: 3,
///     backoff: .exponential(base: 2)
/// )
///
/// // Custom policy for payment processing
/// let paymentRetryPolicy = RetryPolicy(
///     maxAttempts: 5,
///     backoff: .random(range: 1...5)
/// ) { error in
///     guard let apiError = error as? PaymentError else { return false }
///     return apiError.isRetriable
/// }
/// ```
public struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts (initial request + retries)
    /// - Example: maxAttempts = 3 means 1 initial + 2 retries
    let maxAttempts: Int
    
    /// Mathematical strategy for calculating delays between attempts
    let backoff: BackoffStrategy
    
    /// Backoff delay calculation strategies
    public enum BackoffStrategy: Sendable {
        /// Fixed interval between attempts
        /// - Example: `.constant(2.0)` = 2 second delay every time
        case constant(TimeInterval)
        
        /// Exponential delay growth: base^attemptNumber
        /// - Example: `.exponential(base: 2)` = 2s, 4s, 8s delays
        case exponential(base: TimeInterval)
        
        /// Random delay within range for each attempt
        /// - Example: `.random(range: 1...5)` = random 1-5 second delays
        case random(range: ClosedRange<TimeInterval>)
    }
    
    /// Determines if a request should be retried based on the error
    /// - Parameter error: The error encountered during the request
    /// - Returns: Boolean indicating if retry should be attempted
    ///
    /// ## Customization Example
    /// ```swift
    /// func shouldRetry<T: Error>(error: T) -> Bool {
    ///     switch error {
    ///     case let urlError as URLError:
    ///         return [.timedOut, .networkConnectionLost].contains(urlError.code)
    ///     case let apiError as APIError:
    ///         return apiError.statusCode >= 500
    ///     default:
    ///         return false
    ///     }
    /// }
    /// ```
    func shouldRetry<T: Error>(error: T) -> Bool {
        // Default implementation - replace with domain-specific logic
        return true
    }
    
    /// Calculates delay for a specific retry attempt
    /// - Parameter attempt: The retry attempt number (0 = first retry)
    /// - Returns: Time interval to wait before next attempt
    ///
    /// ## Calculation Examples
    /// | Attempt | Constant(2) | Exponential(2) | Random(1...5) |
    /// |------------|--------------------|------------------|---------------|
    /// | 0           | 2.0                  | 2.0                | 3.2            |
    /// | 1           | 2.0                  | 4.0                | 1.7            |
    /// | 2           | 2.0                  | 8.0                | 4.8            |
    func delay(for attempt: Int) -> TimeInterval {
        switch backoff {
        case .constant(let interval):
            return interval
        case .exponential(let base):
            return pow(base, Double(attempt))
        case .random(let range):
            return Double.random(in: range)
        }
    }
}

extension RetryPolicy {
    public static let `default`: RetryPolicy = .init(maxAttempts: 3, backoff: .exponential(base: 2))
}
