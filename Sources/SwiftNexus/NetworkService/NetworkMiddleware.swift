//
//  NetworkMiddleware.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// A protocol for intercepting and modifying network requests/responses
/// - Conforms to `Sendable` for safe use in concurrent contexts
///
/// ## Middleware Pipeline
/// 1. `prepare` called sequentially before sending request
/// 2. `process` called sequentially after receiving response
///
/// ## Common Use Cases
/// - Authentication token injection
/// - Request/response logging
/// - Error handling
/// - Response transformation
/// - Network monitoring
public protocol NetworkMiddleware: Sendable {
    /// Modifies outgoing requests before sending
    /// - Parameter request: Original URLRequest
    /// - Returns: Modified URLRequest
    ///
    /// ## Example: Add auth header
    /// ```swift
    /// func prepare(_ request: URLRequest) async -> URLRequest {
    ///     var request = request
    ///     request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    ///     return request
    /// }
    /// ```
    func prepare(_ request: URLRequest) async -> URLRequest
    
    /// Processes received responses before delivery
    /// - Parameter response: Raw network response
    /// - Returns: Modified response
    ///
    /// ## Example: Response logging
    /// ```swift
    /// func process(response: (Data, URLResponse)) async -> (Data, URLResponse) {
    ///     print("Received response: \((response.1 as? HTTPURLResponse)?.statusCode ?? 0)")
    ///     return response
    /// }
    /// ```
    func process(response: ProcessedResponse) async throws -> ProcessedResponse
}
