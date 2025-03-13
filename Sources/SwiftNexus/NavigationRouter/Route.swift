//
//  Route.swift
//  TestToDiscard
//
//  Created by Diptiranjan Rout on 11/03/25.
//

import Foundation
import SwiftUI

/// A protocol defining navigable routes in an application
///
/// ## Example Usage
/// ```swift
/// enum AppRoute: Route {
///     case home
///     case profile(id: String)
///     case settings
///
///     // MARK: - Route Compliance
///     func view(router: NavigationRouter<AppRoute>) -> some View {
///         switch self {
///         case .home:
///             HomeView()
///         case .profile(let id):
///             ProfileView(id: id)
///         case .settings:
///             SettingsView()
///         }
///     }
///
///     static func parse(from pathComponents: [String], startingAt index: Int) -> (Self, Int)? {
///         guard index < pathComponents.count else { return nil }
///
///         switch pathComponents[index] {
///         case "home":
///             return (.home, 1)
///         case "profile" where pathComponents.count > index + 1:
///             return (.profile(id: pathComponents[index + 1]), 2)
///         case "settings":
///             return (.settings, 1)
///         default:
///             return nil
///         }
///     }
///
///     var pathComponents: [String] {
///         switch self {
///         case .home: return ["home"]
///         case .profile(let id): return ["profile", id]
///         case .settings: return ["settings"]
///         }
///     }
/// }
///
///
/// // 3. Handle deep link: "myapp://profile/456"
/// // Would navigate to profile view with ID "456"
/// // URL: myapp://home -> AppRoute.home
/// // URL: myapp://profile/123 -> AppRoute.profile(id: "123")
/// // URL: myapp://settings -> AppRoute.settings
/// ```
///
/// - Important: Conforming types must be Hashable and implement:
///   - `view(router:)` for view resolution
///   - `parse(from:startingAt:)` for deep link parsing (optional but recommended)
///   - `pathComponents` for deep link generation (optional but recommended)
public protocol Route: Hashable {
    /// The type of view this route will display
    associatedtype RouteView: View
    
    /// Creates the view associated with this route
    /// - Parameter router: The navigation router managing the stack
    @ViewBuilder
    func view(router: NavigationRouter<Self>) -> RouteView
    
    /// Attempts to parse a route from URL path components
    /// - Parameters:
    ///   - pathComponents: Array of string components from a URL path
    ///   - index: Starting index for parsing
    /// - Returns: A tuple containing the parsed route and number of components consumed
    static func parse(from pathComponents: [String], startingAt index: Int) -> (Self, Int)?
    
    /// The path components representing this route in URL format
    var pathComponents: [String] { get }
}

public extension Route {
    /// Default implementation that fails to parse any route
    static func parse(from pathComponents: [String], startingAt index: Int) -> (Self, Int)? {
        guard pathComponents.count > index else { return nil }
        return nil
    }
    
    /// Default implementation returns empty path components
    var pathComponents: [String] { [] }
}
