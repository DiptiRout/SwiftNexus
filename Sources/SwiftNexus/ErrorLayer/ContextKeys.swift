//
//  ContextKeys.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 20/02/25.
//

import Foundation

public struct ContextKeys {
    public var userId: Key<Int> { "user_id" }
    public var requestURL: Key<URL> { "request_url" }
    public var retryCount: Key<Int> { "retry_count" }
    
    public struct Key<Value: Sendable>: ExpressibleByStringLiteral {
        public let name: String
        public init(stringLiteral value: String) { self.name = value }
    }
}
