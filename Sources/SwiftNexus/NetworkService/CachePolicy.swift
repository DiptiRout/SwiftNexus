//
//  CachePolicy.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// Defines caching strategies for network requests
/// - Conforms to `Sendable` for safe use in concurrent contexts
///
/// ## Usage Guide
/// Use these policies to balance freshness vs performance:
/// ```swift
/// struct NewsRequest: RequestPipeline {
///     let cachePolicy: CachePolicy = .returnCacheElseLoad
///     // Other request properties...
/// }
/// ```
public enum CachePolicy: Sendable {
    /// Bypass cache completely, always fetch fresh from network
    /// - Use Case: Real-time data (stock prices, live scores)
    case ignoreCache
    
    /// Check cache first, then network if needed with expiration control
    /// - Parameters:
    ///   - ttl: Time-to-live duration in seconds
    /// - Use Case: Content where stale data is acceptable temporarily
    case returnCacheElseLoad(ttl: TimeInterval)
    
    /// Use cache only, never hit network
    /// - Use Case: Offline mode or bandwidth conservation
    case returnCacheDontLoad
    
    /// Safe TTL accessor with default values
    public var ttl: TimeInterval {
        switch self {
        case .returnCacheElseLoad(let ttl):
            return max(ttl, 0)  // Ensure non-negative values
        default:
            return 0
        }
    }
    
    /// Cache validity status checker
    public var allowsCaching: Bool {
        switch self {
        case .ignoreCache:
            return false
        default:
            return true
        }
    }
}

// MARK: - Convenience Initializers
public extension CachePolicy {
    /// Standard caching policy with recommended TTL values
    static func standardTTL(for dataType: DataType) -> Self {
        switch dataType {
        case .userProfile:
            return .returnCacheElseLoad(ttl: 300)  // 5 minutes
        case .staticContent:
            return .returnCacheElseLoad(ttl: 86400)  // 24 hours
        case .liveData:
            return .ignoreCache
        }
    }
    
    enum DataType {
        case userProfile
        case staticContent
        case liveData
    }
}
