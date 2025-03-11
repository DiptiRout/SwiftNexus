//
//  NetworkSession.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

/// A concurrency-safe protocol abstracting network data tasks
/// - Enables easy mocking/testing and session implementation swapping
/// - Conforms to `Sendable` for safe use in concurrent contexts
///
/// ## Key Features
/// - Async/await native interface
/// - Strict Swift 6 concurrency compliance
/// - Protocol-oriented design for testability
///
/// ## Usage
/// Default implementation using URLSession:
/// ```swift
/// let session: NetworkSession = URLSession.shared
/// ```
///
/// Mock implementation for testing:
/// ```swift
/// struct MockSession: NetworkSession {
///     func data(for request: URLRequest) async throws -> (Data, URLResponse) {
///         return (mockData, HTTPURLResponse(...))
///     }
/// }
/// ```
public protocol NetworkSession: Sendable {
    /// Performs a network data task with modern concurrency support
    /// - Parameter request: URLRequest to execute
    /// - Returns: Tuple containing response data and URLResponse
    /// - Throws: Network-related errors
    ///
    /// ## Example
    /// ```swift
    /// let request = URLRequest(url: URL(string: "https://api.example.com/data")!)
    /// let (data, response) = try await session.data(for: request)
    /// ```
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    
    /// Downloads a file for the given request
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Tuple containing temporary file URL and URLResponse
    /// - Throws: Network-related errors
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
    
    /// Downloads a file with progress updates
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - progress: Async sequence yielding progress values (0.0 to 1.0)
    /// - Returns: Tuple containing temporary file URL and URLResponse
    /// - Throws: Network-related errors
    func download(
        for request: URLRequest,
        progressHandler: @escaping @Sendable (Double) async -> Void
    ) async throws -> (URL, URLResponse)
}

// MARK: - URLSession Conformance
extension URLSession: NetworkSession {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
    
    public func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        try await download(for: request, progressHandler: { _ in })
    }
    
    public func download(
        for request: URLRequest,
        progressHandler: @escaping @Sendable (Double) async -> Void
    ) async throws -> (URL, URLResponse) {
        let delegate = await DownloadProgressDelegate(
            progressHandler: progressHandler
        )
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: OperationQueue.main
        )
        defer { session.finishTasksAndInvalidate() }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Ensure the assignment is performed on the MainActor
                await MainActor.run {
                    delegate.completionHandler = { result in
                        switch result {
                        case .success(let value):
                            continuation.resume(returning: value)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                let task = session.downloadTask(with: request)
                task.resume()
            }
        }
    }
}
