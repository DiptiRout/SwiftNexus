//
//  RSCacheManager.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 15/02/25.
//

import Foundation

public actor CacheManager: CacheProvider {
    private enum CacheEntry {
        case data(Data, storedAt: Date, ttl: TimeInterval)
        case file(URL, storedAt: Date, ttl: TimeInterval)
    }
    
    private var cache: [URL: CacheEntry] = [:]
    private let fileCacheDirectory: URL
    private let fileManager: FileManager
    
    /// Initializes a new cache manager with configurable storage
    /// - Parameters:
    ///   - fileManager: File system manager (default: .default)
    ///   - subdirectory: Cache directory name (default: "NetworkCache")
    ///
    /// ## Example
    /// ```swift
    /// let cache = try CacheManager(subdirectory: "VideoCache")
    /// ```
    public init(
        fileManager: FileManager = .default,
        subdirectory: String = "NetworkCache"
    ) throws {
        self.fileManager = fileManager
        let cachesDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        fileCacheDirectory = cachesDirectory.appendingPathComponent(subdirectory)
        
        try Self.createCacheDirectory(
            at: fileCacheDirectory,
            using: fileManager
        )
    }
    
    // MARK: - Public Interface
    public func store(
        data: Data,
        for url: URL,
        ttl: TimeInterval
    ) {
        cache[url] = .data(data, storedAt: Date(), ttl: ttl)
    }
    
    public func store(
        file sourceURL: URL,
        for url: URL,
        ttl: TimeInterval
    ) async throws {
        let fileName = UUID().uuidString
        let destinationURL = fileCacheDirectory.appendingPathComponent(fileName)
        try await copyFileAtomically(from: sourceURL, to: destinationURL)
        cache[url] = .file(destinationURL, storedAt: Date(), ttl: ttl)
    }
    
    public func getData(for url: URL) -> Data? {
        guard let entry = cache[url] else { return nil }
        
        switch entry {
        case .data(let data, let storedAt, let ttl):
            return validateEntry(url: url, storedAt: storedAt, ttl: ttl) ? data : nil
        case .file:
            return nil
        }
    }
    
    public func getFile(for url: URL) -> URL? {
        guard let entry = cache[url] else { return nil }
        
        switch entry {
        case .file(let fileURL, let storedAt, let ttl):
            return validateEntry(url: url, storedAt: storedAt, ttl: ttl) ? fileURL : nil
        case .data:
            return nil
        }
    }
    
    public func removeAll() async {
        for (url, _) in cache {
            removeEntry(for: url)
        }
    }
    
    // MARK: - Maintenance
    public func cleanup() {
        let now = Date()
        for (url, entry) in cache {
            switch entry {
            case .data(_, let storedAt, let ttl):
                checkExpiration(url: url, storedAt: storedAt, ttl: ttl, now: now)
            case .file(_, let storedAt, let ttl):
                checkExpiration(url: url, storedAt: storedAt, ttl: ttl, now: now)
            }
        }
    }
}

// MARK: - Private Implementation
private extension CacheManager {
    private static nonisolated func createCacheDirectory(
        at url: URL,
        using fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    func copyFileAtomically(from source: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                // Use coordinator for atomic file operations
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                var copyError: Error?
                
                coordinator.coordinate(
                    writingItemAt: destination,
                    options: .forReplacing,
                    error: &coordinationError
                ) { destURL in
                    do {
                        if fileManager.fileExists(atPath: destURL.path) {
                            try fileManager.removeItem(at: destURL)
                        }
                        try fileManager.copyItem(at: source, to: destURL)
                        try fileManager.setAttributes(
                            [.creationDate: Date()],
                            ofItemAtPath: destURL.path
                        )
                    } catch {
                        copyError = error
                    }
                }
                
                if let error = copyError ?? coordinationError {
                    throw error
                }
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func validateEntry(url: URL, storedAt: Date, ttl: TimeInterval) -> Bool {
        guard Date().timeIntervalSince(storedAt) <= ttl else {
            removeEntry(for: url)
            return false
        }
        return true
    }
    
    func checkExpiration(url: URL, storedAt: Date, ttl: TimeInterval, now: Date) {
        guard now.timeIntervalSince(storedAt) > ttl else { return }
        removeEntry(for: url)
    }
    
    func removeEntry(for url: URL) {
        defer { cache.removeValue(forKey: url) }
        
        guard let entry = cache[url] else { return }
        
        switch entry {
        case .file(let fileURL, _, _):
            try? fileManager.removeItem(at: fileURL)
        default:
            break
        }
    }
}
