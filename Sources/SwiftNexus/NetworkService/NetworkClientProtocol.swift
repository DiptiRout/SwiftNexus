import Foundation

public protocol NetworkClientProtocol {
    func request<T: Decodable>(
        url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        parameters: [String: Any]?,
        body: Data?
    ) async throws -> T
    
    func upload(
        file: Data,
        to url: URL,
        method: HTTPMethod,
        headers: [String: String]?
    ) async throws -> Data
    
    func download(
        from url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        parameters: [String: Any]?,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL
}
