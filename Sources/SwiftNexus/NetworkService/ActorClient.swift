//
//  ActorClient 2.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 21/02/25.
//

import Foundation
import CryptoKit

/// A modern actor-based HTTP client with built-in caching, retries, and middleware support
///
/// ## Example Usage
/// ```swift
/// // Basic initialization without caching
/// let client = ActorClient(baseURL: URL(string: "https://api.example.com"))
///
/// // Initialization with default caching
/// do {
///     let cachedClient = try ActorClient.withDefaultCache(
///         baseURL: URL(string: "https://api.example.com"),
///         cacheLifetime: 300 // 5 minutes
///     )
/// } catch {
///     print("Failed to initialize cache: \(error)")
/// }
/// ```
public actor ActorClient {
    // MARK: - Configuration Properties
    
    /// Underlying network session handling URL requests
    private let session: NetworkSession
    
    /// Base URL for all requests
    private let baseURL: URL?
    
    /// JSON decoder for response parsing
    private let decoder: JSONDecoder
    
    /// Middleware pipeline for request/response processing
    private let middlewares: [NetworkMiddleware]
    
    /// Default headers added to all requests
    private let defaultHeaders: [String: String]
    
    /// Default query parameters added to all requests
    private let defaultQueryParams: [String: String]
    
    /// Default request body for all requests
    private let defaultBody: Data?
    
    /// File manager for download operations
    private nonisolated(unsafe) let fileManager: FileManager
    
    /// Optional cache provider for response caching
    private let cacheProvider: (any CacheProvider)?
    
    // MARK: - Initialization
    
    /// Initializes a new networking client
    /// - Parameters:
    ///   - baseURL: Root endpoint for all requests
    ///   - session: Network session (default: URLSession.shared)
    ///   - decoder: JSON decoder (default: JSONDecoder())
    ///   - middlewares: Array of request/response processors
    ///   - defaultHeaders: Headers added to all requests
    ///   - defaultQueryParams: Query parameters added to all requests
    ///   - defaultBody: Default request body
    ///   - fileManager: File system manager (default: .default)
    ///   - cacheProvider: Optional cache implementation
    public init(
        baseURL: URL?,
        session: NetworkSession = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder(),
        middlewares: [NetworkMiddleware] = [],
        defaultHeaders: [String: String] = [:],
        defaultQueryParams: [String: String] = [:],
        defaultBody: Data? = nil,
        fileManager: FileManager = .default,
        cacheProvider: (any CacheProvider)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.middlewares = middlewares
        self.defaultHeaders = defaultHeaders
        self.defaultQueryParams = defaultQueryParams
        self.defaultBody = defaultBody
        self.fileManager = fileManager
        self.cacheProvider = cacheProvider
    }
    
    /// Convenience initializer with default caching
    /// - Parameters:
    ///   - cacheLifetime: Default cache TTL in seconds
    public static func withDefaultCache(
        baseURL: URL?,
        session: NetworkSession = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder(),
        middlewares: [NetworkMiddleware] = [],
        defaultHeaders: [String: String] = [:],
        defaultQueryParams: [String: String] = [:],
        defaultBody: Data? = nil,
        fileManager: FileManager = .default,
        cacheLifetime: TimeInterval = 300
    ) throws -> Self {
        let cache = try CacheManager()
        
        return Self(
            baseURL: baseURL,
            session: session,
            decoder: decoder,
            middlewares: middlewares,
            defaultHeaders: defaultHeaders,
            defaultQueryParams: defaultQueryParams,
            defaultBody: defaultBody,
            cacheProvider: cache
        )
    }
}

// MARK: - Public Interface
extension ActorClient {
    /// Executes a network request with automatic retry logic
    /// ## Example
    /// ```swift
    /// struct UserRequest: RequestPipeline {
    ///     typealias ResponseType = [User]
    ///     typealias ErrorType = APIError
    ///     
    ///     let path = "/users"
    ///     let method = HTTPMethod.get
    ///     let cachePolicy: CachePolicy = .returnCacheElseLoad(ttl: 60)
    /// }
    /// let users = try await client.send(UserRequest())
    /// ```
    public func send<T: RequestPipeline>(_ request: T) async throws -> T.ResponseType {
        try await handleRequest(request, type: .data)
    }

    /// Downloads a file with progress tracking and integrity verification
    /// ## Example
    /// ```swift
    /// struct ReportDownload: DownloadRequestPipeline {
    ///     let path = "/files/report.pdf"
    ///     let method = HTTPMethod.get
    ///     let downloadConfig = DownloadConfig(
    ///         destination: documentsDirectory.appendingPathComponent("report.pdf"),
    ///         overwrite: true,
    ///         checksum: "sha256:abc123..."
    ///     )
    /// }
    /// let fileURL = try await client.download(ReportDownload())
    /// ```
    public func download<T: DownloadRequestPipeline>(_ request: T) async throws -> URL {
        try await handleRequest(request, type: .download(request.downloadConfig))
    }

    /// Streams download progress with final file URL
    /// ## Example
    /// ```swift
    /// let stream = client.downloadWithProgressStream(ReportDownload())
    /// for try await event in stream {
    ///     switch event {
    ///     case .progress(let progress):
    ///         print("Download progress: \(progress * 100)%")
    ///     case .completed(let url):
    ///         print("Download completed at \(url)")
    ///     }
    /// }
    /// ```
    nonisolated public func downloadWithProgressStream<T: DownloadRequestPipeline>(
        _ request: T
    ) -> AsyncThrowingStream<DownloadProgressEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let fileURL = try await handleRequest(
                        request,
                        type: .downloadWithProgress(request.downloadConfig, progress: { progress in
                            continuation.yield(DownloadProgressEvent.progress(progress))
                        })
                    )
                    // When complete, yield the final file URL.
                    continuation.yield(DownloadProgressEvent.completed(fileURL))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Request Handling
extension ActorClient {
    /// Unified request type handling both data and download operations
    public enum APIRequestType {
        case data
        case download(DownloadConfig)
        case downloadWithProgress(DownloadConfig, progress: @Sendable (Double) -> Void)
    }

    /// Progress events for download operations
    public enum DownloadProgressEvent {
        case progress(Double)
        case completed(URL)
    }

    private func constructRequest<T: BaseRequestPipeline>(_ request: T) async throws -> URLRequest {
        try validateMethodSafety(for: request)
        let mergedHeaders = defaultHeaders.merging(request.headers) { $1 }
        let mergedQueryParams = defaultQueryParams.merging(request.queryParameters) { $1 }
        let finalBody = request.body ?? defaultBody
        
        guard let baseURL = baseURL,
              var components = URLComponents(
                url: baseURL.appendingPathComponent(request.path),
                resolvingAgainstBaseURL: false),
              !request.path.isEmpty else {
            throw URLError(.badURL)
        }
        
        components.queryItems = mergedQueryParams.map(URLQueryItem.init)
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = mergedHeaders
        urlRequest.httpBody = finalBody
        
        return urlRequest
    }

    /// Validates RESTful constraints for HTTP method usage
    private func validateMethodSafety<T: BaseRequestPipeline>(for request: T) throws {
        // Safe methods (GET/HEAD) shouldn't have request bodies
        if request.method.isSafe && request.body != nil {
            throw URLError(.unsupportedURL, userInfo: [
                NSLocalizedDescriptionKey: "Safe HTTP methods cannot have request bodies",
                "Method": request.method.rawValue
            ])
        }
        
        // Non-safe methods shouldn't use aggressive caching
        if !request.method.isSafe {
            if case .returnCacheElseLoad = request.cachePolicy {
                throw URLError(.unsupportedURL, userInfo: [
                    NSLocalizedDescriptionKey: "Non-safe methods cannot use cache-first policy",
                    "Method": request.method.rawValue,
                    "CachePolicy": String(describing: request.cachePolicy)
                ])
            }
        }
    }
}

// MARK: - Middleware
extension ActorClient {
    /// Applies middleware pipeline to requests
    /// - Example: Create a request logger
    /// ```swift
    /// struct LoggingMiddleware: NetworkMiddleware {
    ///     func prepare(_ request: URLRequest) async -> URLRequest {
    ///         print("Outgoing request: \(request)")
    ///         return request
    ///     }
    /// }
    /// ```
    private func applyMiddlewares(_ request: URLRequest) async -> URLRequest {
        var currentRequest = request
        for middleware in middlewares {
            currentRequest = await middleware.prepare(currentRequest)
        }
        return currentRequest
    }

    /// Processes responses through middleware chain
    private func processResponse(_ response: (Data, URLResponse)) async throws -> ProcessedResponse {
        var processed = ProcessedResponse(
            data: response.0,
            fileURL: nil,
            urlResponse: response.1
        )
        
        for middleware in middlewares {
            processed = try await middleware.process(response: processed)
        }
        
        return processed
    }

    private func processDownloadResponse(_ response: (URL, URLResponse)) async throws -> ProcessedResponse {
        var processed = ProcessedResponse(
            data: nil,
            fileURL: response.0,
            urlResponse: response.1
        )
        
        for middleware in middlewares {
            processed = try await middleware.process(response: processed)
        }
        
        return processed
        
    }
}

// MARK: - Response Handling
extension ActorClient {
    private func handleStatusCode<T: BaseRequestPipeline>(
        response: ProcessedResponse,
        httpResponse: HTTPURLResponse,
        request: T,
        apiRequestType: APIRequestType
    ) async throws -> T.ResponseType {
        switch httpResponse.statusCode {
        case 200..<300:
            try await cacheIfNeeded(
                response: response,
                request: request,
                type: apiRequestType
            )
            return try decodeResponse(
                response,
                request: type(of: request),
                requestType: apiRequestType
            )
        case 400..<500:
            throw try handleClientError(
                data: response.data ?? Data(),
                statusCode: httpResponse.statusCode,
                for: request
            )
        default:
            throw NetworkError<T.ErrorType>.serverError(
                statusCode: httpResponse.statusCode,
                data: response.data ?? Data()
            )
        }
    }

    /// Decodes responses according to request type
    /// - Handles both JSON decoding and file downloads
    private func decodeResponse<T: BaseRequestPipeline>(
        _ response: ProcessedResponse,
        request: T.Type,
        requestType: APIRequestType
    ) throws -> T.ResponseType {
        switch requestType {
        case .data:
            guard let data = response.data else {
                throw NetworkError<T.ErrorType>.decodingFailure(
                    DecodingError.dataCorrupted(.init(
                        codingPath: [], debugDescription: "Missing response data for data request")
                    )
                )
            }
            return try decoder.decode(T.ResponseType.self, from: data)
            
        case .download(let config):
            guard let tempURL = response.fileURL else {
                throw NetworkError<T.ErrorType>.fileError(
                    FileError.invalidTemporaryFile
                )
            }
            guard let result = try handleDownload(tempURL: tempURL, config: config) as? T.ResponseType else {
                throw DecodingError.typeMismatch(
                    T.ResponseType.self,
                    .init(
                        codingPath: [],
                        debugDescription: """
                        Download type mismatch. Expected \(T.ResponseType.self), \
                        got \(type(of: try handleDownload(tempURL: tempURL, config: config)))
                        """
                    )
                )
            }
            return result
        default: break
        }
        // TODO: - Here need changes
        throw NetworkError<T.ErrorType>.fileError(
            FileError.invalidTemporaryFile
        )
    }

    /// Handles 4xx client errors with type-safe error models
    private func handleClientError<T: BaseRequestPipeline>(
        data: Data,
        statusCode: Int,
        for request: T
    ) throws -> NetworkError<T.ErrorType> {
        do {
            let errorModel = try decoder.decode(T.ErrorType.self, from: data)
            return .clientError(statusCode: statusCode, errorModel: errorModel)
        } catch {
            return .decodingFailure(error)
        }
    }
}

// MARK: - Caching
extension ActorClient {
    /// Retrieves cached responses when available
    /// - Supports both memory and disk caching strategies
    private func handleCachedResponse<T: BaseRequestPipeline>(
        for key: URL,
        request: T.Type,
        type: APIRequestType
    ) async throws -> T.ResponseType? {
        switch type {
        case .data:
            guard let cachedData = await cacheProvider?.getData(for: key) else {
                return nil
            }
            return try decodeResponse(
                ProcessedResponse(
                    data: cachedData,
                    fileURL: nil,
                    urlResponse: URLResponse()
                ),
                request: T.self,
                requestType: type
            )
            
        case .download(let config):
            guard let cachedFileURL = await cacheProvider?.getFile(for: key) else {
                return nil
            }
            // Verify file integrity before returning cached value
            if let checksum = config.checksum {
                try validateChecksum(for: cachedFileURL, expected: checksum)
            }
            return cachedFileURL as? T.ResponseType
            
        default: break
        }
        // TODO: - Here need changes
        return nil

    }

    /// Caches successful responses based on request policy
    private func cacheIfNeeded<T: BaseRequestPipeline>(
        response: ProcessedResponse,
        request: T,
        type: APIRequestType
    ) async throws {
        guard request.method.isSafe else { return }
        guard let responseURL = response.urlResponse?.url else {
            throw NetworkError<T.ErrorType>.networkFailure(
                URLError(.badURL, userInfo: [
                    NSLocalizedDescriptionKey: "Missing response URL for caching",
                    "Response": "\(response)"
                ])
            )
            }
        
        switch type {
        case .data:
            if let data = response.data {
                await cacheProvider?.store(
                    data: data,
                    for: responseURL,
                    ttl: request.cachePolicy.ttl
                )
            }
            
        case .download(let config):
            if response.fileURL != nil {
                do {
                    try await cacheProvider?.store(
                        file: config.destination,
                        for: responseURL,
                        ttl: request.cachePolicy.ttl
                    )
                } catch FileError.fileExists {
                    // Handle file exists case
                    if config.overwrite {
                        try await cacheProvider?.store(
                            file: config.destination,
                            for: responseURL,
                            ttl: request.cachePolicy.ttl
                        )
                    }
                } catch {
                    throw NetworkError<T.ErrorType>.fileError(error)
                }
            }
        default: break

        }
    }
}

// MARK: - File Downloads
extension ActorClient {
    /// Validates downloaded file integrity using checksums
    /// - Supports SHA256 hashing by default
    private func validateChecksum(for fileURL: URL, expected: String) throws {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data).description
        guard hash == expected else {
            throw FileError.checksumMismatch
        }
    }

    /// Handles file system operations for downloads
    private func handleDownload(
        tempURL: URL,
        config: DownloadConfig
    ) throws -> URL {
        do {
            if fileManager.fileExists(atPath: config.destination.path) {
                guard config.overwrite else {
                    throw FileError.fileExists
                }
                try fileManager.removeItem(at: config.destination)
            }
            
            try fileManager.createDirectory(
                at: config.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            try fileManager.moveItem(at: tempURL, to: config.destination)
            
            if let checksum = config.checksum {
                try validateChecksum(for: config.destination, expected: checksum)
            }
            
            return config.destination
        } catch {
            throw NetworkError<Never>.fileError(error)
        }
    }
}

// MARK: - Retry Logic
extension ActorClient {
    /// Implements exponential backoff for retry attempts
    /// - Base delay: 1 second, multiplier: 2, max delay: 60 seconds
    private nonisolated func calculateBackoff(
        attempt: Int,
        policy: RetryPolicy
    ) async -> UInt64 {
        let delaySeconds = policy.delay(for: attempt)
        return UInt64(delaySeconds * 1_000_000_000)
    }
}

// MARK: - Core Implementation
extension ActorClient {
    private func handleRequest<T: BaseRequestPipeline>(
        _ request: T,
        type: APIRequestType
    ) async throws -> T.ResponseType {
        let maxAttempts = request.retryPolicy.maxAttempts
        
        for attempt in 0..<maxAttempts {
            do {
                return try await attemptRequest(request, apiRequestType: type)
            } catch let error as NetworkError<T.ErrorType> {
                // Check retry conditions
                guard request.method.isIdempotent,
                      request.retryPolicy.shouldRetry(error: error),
                      attempt < maxAttempts - 1 else {
                    throw error // Propagate non-retryable or final attempt errors
                }
                
                let delay = await calculateBackoff(
                    attempt: attempt,
                    policy: request.retryPolicy
                )
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw NetworkError<T.ErrorType>.retryLimitExceeded
    }

    private func attemptRequest<T: BaseRequestPipeline>(
        _ request: T,
        apiRequestType: APIRequestType
    ) async throws -> T.ResponseType {
        let urlRequest = try await constructRequest(request)
        let cacheKey = try request.cacheKey(baseURL: baseURL)
        
        if request.method.isSafe {
            if case .returnCacheElseLoad = request.cachePolicy {
                if let cached = try await handleCachedResponse(
                    for: cacheKey,
                    request: type(of: request),
                    type: apiRequestType
                ) {
                    return cached
                }
            }
        }
        
        let processedRequest = await applyMiddlewares(urlRequest)
        let processedResponse: ProcessedResponse
        switch apiRequestType {
        case .data:
            let (data, response) = try await session.data(for: processedRequest)
            processedResponse = try await processResponse((data, response))
            
        case .download:
            let (tempURL, response) = try await session.download(for: processedRequest)
            processedResponse = try await processDownloadResponse((tempURL, response))
        
        case .downloadWithProgress(_, let progress):

            let (tempURL, response) = try await session.download(
                for: processedRequest,
                progressHandler: progress
            )
            processedResponse = try await processDownloadResponse((tempURL, response))
        }
        
        guard let httpResponse = processedResponse.urlResponse as? HTTPURLResponse else {
            throw NetworkError<T.ErrorType>.networkFailure(URLError(.badServerResponse))
        }
        
        return try await handleStatusCode(
            response: processedResponse,
            httpResponse: httpResponse,
            request: request,
            apiRequestType: apiRequestType
        )
    }
}

// MARK: - Supporting Types
/// Configuration for download operations
public struct DownloadConfig: Sendable {
    let destination: URL
    let overwrite: Bool
    let checksum: String?
}
