//
//  ErrorConvertible.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 20/02/25.
//

import Foundation

// MARK: - Error Conversion
public protocol ErrorConvertible: Error {
    func toUnifiedError(file: String, line: Int) -> UnifiedError
}

public extension Error {
    func toUnifiedError(file: String = #fileID, line: Int = #line) -> UnifiedError {
        (self as? ErrorConvertible)?.toUnifiedError(file: file, line: line) ?? .generic(error: self, file: file, line: line)
    }
}

// MARK: - Error Handling Utilities
public func withErrorHandling<T>(
    _ operation: () async throws -> T,
    file: String = #fileID,
    line: Int = #line
) async -> Result<T, UnifiedError> {
    do {
        return .success(try await operation())
    } catch let error as ErrorConvertible {
        return .failure(error.toUnifiedError(file: file, line: line))
    } catch {
        return .failure(UnifiedError.generic(error: error, file: file, line: line))
    }
}
