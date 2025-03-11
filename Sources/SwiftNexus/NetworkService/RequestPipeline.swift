//
//  RequestPipeline.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// A type-safe protocol defining network requests and their handling rules
/// - Requires: Swift Concurrency (Sendable) and Swift 6 for strict concurrency
///
/// ## Protocol Requirements
/// | Property/Method       | Description                         | Default Implementable |
/// |---------------------- |-------------------------------------|-------------------------------|
/// | `ResponseType`        | Successful response model type      | NO
/// | `ErrorType`           | Error model for 4xx responses       | NO
/// | `path`                | API endpoint path                   | NO
/// | `method`              | HTTP method (GET/POST/etc)          | NO
/// | `headers`             | Request headers                     | YES (empty)
/// | `queryParameters`     | URL query items                     | YES (empty)
/// | `body`                | Request body data                   | YES (nil)
/// | `cachePolicy`         | Caching strategy                    | NO
/// | `retryPolicy`         | Retry behavior rules                | NO
///
/// ## Example Request
/// ```swift
/// struct UserProfileRequest: RequestPipeline {
///     typealias ResponseType = UserProfile
///     typealias ErrorType = APIError
///
///     let userID: String
///
///     var path: String { "/users/\(userID)" }
///     var method: HTTPMethod = .get
///     var headers: [String: String] = ["Accept": "application/json"]
///     var queryParameters: [String: String] = ["details": "full"]
///     var body: Data? = nil
///     var cachePolicy: CachePolicy = .returnCacheElseLoad
///     var retryPolicy: RetryPolicy = .default
/// }
///
/// struct APIError: Decodable, Error {
///     let code: Int
///     let message: String
/// }
/// ```
public protocol BaseRequestPipeline: Sendable {
    /// The expected success response type (must be Decodable)
    associatedtype ResponseType: Sendable & Decodable
    
    /// The error type for 4xx client errors (must be Decodable)
    associatedtype ErrorType: Sendable & Decodable & Error
    
    /// API endpoint path (e.g., "/users/profile")
    var path: String { get }
    
    /// HTTP method for the request
    var method: HTTPMethod { get }
    
    /// HTTP headers to include in request
    var headers: [String: String] { get }
    
    /// URL query parameters
    var queryParameters: [String: String] { get }
    
    /// Request body data (for POST/PUT/PATCH)
    var body: Data? { get }
    
    /// Caching strategy for this request
    var cachePolicy: CachePolicy { get }
    
    /// Retry behavior configuration
    var retryPolicy: RetryPolicy { get }
    
    /// Generates unique cache key URL for the request
    /// - Parameter baseURL: Client's base URL
    func cacheKey(baseURL: URL?) throws -> URL

}

extension BaseRequestPipeline {
    public func cacheKey(baseURL: URL?) throws -> URL {
        guard let base = baseURL else {
            throw URLError(.badURL, userInfo: [
                NSLocalizedDescriptionKey: "Missing base URL"
            ])
        }
        
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        
        components.queryItems = queryParameters.map(URLQueryItem.init)
        return components.url!
    }
}

// MARK: - Default Implementations
public extension RequestPipeline {
    var headers: [String: String] { [:] }
    var queryParameters: [String: String] { [:] }
    var body: Data? { nil }
    var cachePolicy: CachePolicy { .ignoreCache }
    var retryPolicy: RetryPolicy { .default }
}

// MARK: - Best Practices
/// 1. Keep requests small and focused on single responsibilities
/// 2. Prefer composition over inheritance for request variations
/// 3. Use type inference for reusable configurations:
///
/// ```swift
/// protocol JSONRequest: RequestPipeline {
///     var headers: [String: String] { ["Content-Type": "application/json"] }
/// }
///
/// struct UpdateProfileRequest: JSONRequest {
///     var method: HTTPMethod = .put
///     var path: String = "/profile"
///     var body: Data? // JSON encoded
///     //... other requirements
/// }
/// ```

public protocol RequestPipeline: BaseRequestPipeline where ResponseType: Decodable {}

public protocol DownloadRequestPipeline: BaseRequestPipeline where ResponseType == URL {
    var downloadConfig: DownloadConfig { get }
}
