//
//  NavigationTests.swift
//  HLS App
//
//  Created by Diptiranjan Rout on 13/03/25.
//

import Testing
import SwiftUI
@testable import SwiftNexus

struct NavigationTests {
    // MARK: - Basic Navigation Tests
    
    @Test func initialNavigationStateIsEmpty() async throws {
        let router = await NavigationRouter<TestRoute>()
        await #expect(router.path.isEmpty)
    }
    
    @Test func pushAddsToNavigationPath() async throws {
        let router = await NavigationRouter<TestRoute>()
        await router.push(.settings)
        await #expect(router.path.count == 1)
    }
    
    @Test func popRemovesFromNavigationPath() async throws {
        let router = await NavigationRouter<TestRoute>()
        await router.push(.settings)
        await router.pop()
        await #expect(router.path.isEmpty)
    }
    
    // MARK: - Deep Link Tests
    
    @Test func validDeepLinkUpdatesPath() async throws {
        let router = await NavigationRouter<TestRoute>()
        let url = try #require(URL(string: "testscheme://profile/123"))
        
        await router.handleDeepLink(url)
        await #expect(router.path.count == 1)
    }
    
    @Test func invalidDeepLinkDoesntModifyPath() async throws {
        let router = await NavigationRouter<TestRoute>()
        let url = try #require(URL(string: "invalid://url"))
        
        await router.handleDeepLink(url)
        await #expect(router.path.isEmpty)
    }
    
    // MARK: - Route Parsing Tests
    
    @Test func routeParsingValidProfileURL() async throws {
        let components = ["profile", "456"]
        let result = TestRoute.parse(from: components, startingAt: 0)
        let (route, consumed) = try #require(result)
        
        #expect(route == .profile(id: "456"))
        #expect(consumed == 2)
    }
    
    @Test func routeParsingInvalidURLReturnsNil() async throws {
        let components = ["invalid", "component"]
        let result = TestRoute.parse(from: components, startingAt: 0)
        #expect(result == nil)
    }
}

// MARK: - Test Helpers

private enum TestRoute: Route {
    case home
    case settings
    case profile(id: String)
    
    @ViewBuilder
    func view(router: NavigationRouter<TestRoute>) -> some View {
        switch self {
        case .home: Text("Home")
        case .settings: Text("Settings")
        case .profile(let id): Text("Profile \(id)")
        }
    }
    
    static func parse(from pathComponents: [String], startingAt index: Int) -> (Self, Int)? {
        guard pathComponents.count > index else { return nil }
        
        switch pathComponents[index] {
        case "profile" where pathComponents.count > index + 1:
            return (.profile(id: pathComponents[index + 1]), 2)
        default:
            return nil
        }
    }
    
    var pathComponents: [String] {
        switch self {
        case .profile(let id): return ["profile", id]
        default: return []
        }
    }
}
