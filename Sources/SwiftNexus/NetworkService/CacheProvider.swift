//
//  CacheProvider.swift
//  NetworkKit
//
//  Created by Diptiranjan Rout on 19/02/25.
//

import Foundation

public protocol CacheProvider: Sendable {
    func store(data: Data, for key: URL, ttl: TimeInterval) async
    func store(file: URL, for key: URL, ttl: TimeInterval) async throws
    func getData(for key: URL) async -> Data?
    func getFile(for key: URL) async -> URL?
}
