//
//  NavigationTests.swift
//  HLS App
//
//  Created by Diptiranjan Rout on 13/03/25.
//

import Testing
import SwiftUI
@testable import SwiftNexus

@MainActor
struct NavigationTests {
    // MARK: - Basic Navigation Tests
    
    @Test func initialNavigationStateIsEmpty() {
        let router = NavigationRouter<TestRoute>()
        #expect(router.path.isEmpty)
    }
    
    @Test func pushAddsToNavigationPath() {
        let router = NavigationRouter<TestRoute>()
        router.push(.settings)
        #expect(router.path.count == 1)
    }
    
    @Test func pushToIndex() {
        let router = NavigationRouter<TestRoute>()
        router.push(.home)
        router.push(.settings)
        #expect(router.path.count == 2)
        router.popTo(index: 0)
        #expect(router.path.count == 1)
    }
    
    @Test func popRemovesFromNavigationPath() {
        let router = NavigationRouter<TestRoute>()
        router.push(.settings)
        router.pop()
        #expect(router.path.isEmpty)
    }
    
    // MARK: - Deep Link Tests
    
    @Test func validDeepLinkUpdatesPath() {
        let router = NavigationRouter<TestRoute>()
        do {
            let url = try #require(URL(string: "testscheme://profile/123"))
            
            router.handleDeepLink(url)
            #expect(router.path.count == 1)
        } catch {
            #expect(Bool(false))
        }
    }
    
    @Test func invalidDeepLinkDoesntModifyPath() {
        let router = NavigationRouter<TestRoute>()
        do {
            let url = try #require(URL(string: "invalid://url"))
            
            router.handleDeepLink(url)
            #expect(router.path.isEmpty)
        } catch {
            #expect(Bool(false))
        }
    }
    
    // MARK: - Route Parsing Tests
    
    @Test func routeParsingValidProfileURL() {
        let components = ["profile", "456"]
        let result = TestRoute.parse(from: components, startingAt: 0)
        do {
            let (route, consumed) = try #require(result)
            
            #expect(route == .profile(id: "456"))
            #expect(consumed == 2)
        } catch {
            #expect(Bool(false))
        }
    }
    
    @Test func routeParsingInvalidURLReturnsNil() {
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
