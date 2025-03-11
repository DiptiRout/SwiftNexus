//
//  HTTPMethod.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

/// Represents standard HTTP methods defined by RFC 9110 and common extensions
///
/// ## Overview
/// Use this enum to declare safe, idempotent HTTP operations in a type-safe manner.
/// Conforms to `Sendable` for safe use in concurrent contexts.
///
/// ## Examples
/// ### Common Usage Patterns
/// ```swift
/// var request = URLRequest(url: url)
/// request.httpMethod = HTTPMethod.post.rawValue
/// ```
///
/// ### With Networking Layer
/// ```swift
/// struct CreateUserRequest: RequestPipeline {
///     let method: HTTPMethod = .post
///     let path = "/users"
///     let body: Data
/// }
/// ```
public enum HTTPMethod: String, Sendable {
    /// GET - Retrieve resource representation
    /// - Idempotent: Yes
    /// - Safe: Yes
    /// - Body allowed: No (typically)
    /// - Example: Fetch user profile
    /// ```swift
    /// HTTPMethod.get → GET /users/123
    /// ```
    case get
    
    /// POST - Process resource representation
    /// - Idempotent: No
    /// - Safe: No
    /// - Body allowed: Yes
    /// - Example: Create new user
    /// ```swift
    /// HTTPMethod.post → POST /users
    /// ```
    case post
    
    /// PUT - Replace resource entirely
    /// - Idempotent: Yes
    /// - Safe: No
    /// - Body allowed: Yes
    /// - Example: Update user profile
    /// ```swift
    /// HTTPMethod.put → PUT /users/123
    /// ```
    case put
    
    /// DELETE - Remove resource
    /// - Idempotent: Yes
    /// - Safe: No
    /// - Body allowed: No (typically)
    /// - Example: Remove user account
    /// ```swift
    /// HTTPMethod.delete → DELETE /users/123
    /// ```
    case delete
    
    /// PATCH - Partial resource update
    /// - Idempotent: No
    /// - Safe: No
    /// - Body allowed: Yes
    /// - Example: Update user email
    /// ```swift
    /// HTTPMethod.patch → PATCH /users/123
    /// ```
    case patch
    
    /// HEAD - Retrieve metadata only
    /// - Idempotent: Yes
    /// - Safe: Yes
    /// - Body allowed: No
    /// - Example: Check resource existence
    /// ```swift
    /// HTTPMethod.head → HEAD /users/123
    /// ```
    case head
    
    /// OPTIONS - List communication options
    /// - Idempotent: Yes
    /// - Safe: Yes
    /// - Body allowed: No
    /// - Example: CORS preflight requests
    /// ```swift
    /// HTTPMethod.options → OPTIONS /users
    /// ```
    case options
}

// MARK: - Best Practices
extension HTTPMethod {
    /// Check if method is considered idempotent (repeatable without side effects)
    public var isIdempotent: Bool {
        switch self {
        case .get, .put, .delete, .head, .options: return true
        case .post, .patch: return false
        }
    }
    
    /// Check if method is considered safe (no server state modification)
    public var isSafe: Bool {
        switch self {
        case .get, .head, .options: return true
        case .post, .put, .delete, .patch: return false
        }
    }
}
