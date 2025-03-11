//
//  DownloadProgressDelegate.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 19/02/25.
//

import Foundation

@MainActor
public final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: @Sendable (Double) async -> Void
    private let progressState = ProgressState()
    public var completionHandler: ((Result<(URL, URLResponse), Error>) -> Void)?
    
    public init(progressHandler: @escaping @Sendable (Double) async -> Void) {
        self.progressHandler = progressHandler
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor [weak self] in
            await self?.handleProgressUpdate(progress)
        }
    }
    
    // Required delegate method for download completion
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            guard let response = downloadTask.response else {
                self.completionHandler?(.failure(URLError(.badServerResponse)))
                return
            }
            self.completionHandler?(.success((location, response)))
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                self.completionHandler?(.failure(error))
            }
        }
    }
    
    private func handleProgressUpdate(_ progress: Double) async {
        // Proper actor-bound state modification
        await progressState.update(progress: progress)
        await progressHandler(progress)
    }
    
    private actor ProgressState {
        private(set) var lastProgress: Double = 0.0
        
        func update(progress: Double) {
            lastProgress = progress
        }
    }
}
