//
//  AdditionalData.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 20/02/25.
//


// MARK: - Additional Data Implementation
@dynamicMemberLookup
public struct AdditionalData: Sendable {
    public struct Key<Value: Sendable>: ExpressibleByStringLiteral, Hashable, Sendable {
        public let name: String
        
        public init(stringLiteral value: String) {
            self.name = value
        }
    }
    
    private var storage: [String: any Sendable] = [:]
    
    public init() {}
    
    public subscript<Value: Sendable>(
            dynamicMember keyPath: KeyPath<ContextKeys, ContextKeys.Key<Value>>
        ) -> Value? {
            get {
                let key = ContextKeys()[keyPath: keyPath]
                return storage[key.name] as? Value
            }
            set {
                let key = ContextKeys()[keyPath: keyPath]
                storage[key.name] = newValue
            }
        }

    public subscript<Value: Sendable>(key: Key<Value>) -> Value? {
        get { storage[key.name] as? Value }
        set { storage[key.name] = newValue }
    }
    
    public var allValues: [String: any Sendable] { storage }
}
