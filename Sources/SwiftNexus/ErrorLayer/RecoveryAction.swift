//
//  RecoveryAction.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 20/02/25.
//

import Foundation

// MARK: - Recovery Action
public struct RecoveryAction: Sendable {
    public let id = UUID()
    public let title: String
    public let action: @Sendable () -> Void
    
    public init(title: String, action: @escaping @Sendable () -> Void) {
        self.title = title
        self.action = action
    }
}
