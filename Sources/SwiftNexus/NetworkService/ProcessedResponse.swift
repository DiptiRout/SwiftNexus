//
//  ProcessedResponse.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 19/02/25.
//

import Foundation

public struct ProcessedResponse: Sendable {
    public let data: Data?
    public let fileURL: URL?
    public let urlResponse: URLResponse?
    public let statusCode: Int
//    public let headers: [String: String]
    
    public init(
        data: Data?,
        fileURL: URL?,
        urlResponse: URLResponse
    ) {
        self.data = data
        self.fileURL = fileURL
        self.urlResponse = urlResponse
        
        if let httpResponse = urlResponse as? HTTPURLResponse {
            self.statusCode = httpResponse.statusCode
//            self.headers = httpResponse.allHeaderFields
//                .compactMapValues { $0 as? String }
        } else {
            self.statusCode = 0
//            self.headers = [:]
        }
    }
}
