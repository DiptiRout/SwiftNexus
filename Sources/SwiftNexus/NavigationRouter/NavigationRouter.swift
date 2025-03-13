//
//  NavigationRouter.swift
//  TestToDiscard
//
//  Created by Diptiranjan Rout on 11/03/25.
//

import SwiftUI

/// A navigation router that manages stack-based navigation and deep link handling
///
@MainActor
@Observable
public final class NavigationRouter<MainRoute: Route>: Sendable {
    /// The navigation stack path managed by SwiftUI NavigationStack
    public var path = NavigationPath()
    
    /// Creates a new navigation router instance
    public init() {}
    
    // MARK: - Navigation Methods
    
    /// Push a new route onto the navigation stack
    /// - Parameter route: The route to navigate to
    public func push(_ route: MainRoute) {
        path.append(route)
    }
    
    /// Pop the top-most view from the navigation stack
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    /// Navigate back to a specific position in the stack
    /// - Parameter index: The destination stack index (0-based)
    public func popTo(index: Int) {
        guard path.count > index && index >= 0 else { return }
        let countToRemove = path.count - index - 1
        path.removeLast(countToRemove)
    }
    
    /// Reset navigation stack to root view
    public func popToRoot() {
        path.removeLast(path.count)
    }
    
    // MARK: - Deep Link Handling
    
    /// Handles deep link URLs and converts them to navigation routes
    /// - Parameter url: The URL to process (format: "scheme://host/path/components")
    ///
    /// ## URL Structure Example
    /// "myapp://profile/123" would parse to:
    /// - Scheme: "myapp"
    /// - Host: "profile"
    /// - Path components: ["123"]
    public func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = components.scheme,
              let host = components.host else { return }
        
        // Build path components array: [scheme, host, path...]
        var pathComponents = [scheme, host]
        pathComponents += components.path.split(separator: "/").map(String.init)
        
        var routes: [MainRoute] = []
        var currentIndex = 0
        
        // Parse components into routes using Route's parsing capability
        while currentIndex < pathComponents.count {
            if let (route, consumed) = MainRoute.parse(from: pathComponents, startingAt: currentIndex) {
                routes.append(route)
                currentIndex += consumed
            } else {
                currentIndex += 1
            }
        }
        
        guard !routes.isEmpty else { return }
        
        // Update navigation stack on main thread
        self.navigate(routes)
    }
    
    /// Private method to execute deep link navigation sequence
    private func navigate(_ routes: [MainRoute]) {
        popToRoot()
        routes.forEach { push($0) }
    }
}
