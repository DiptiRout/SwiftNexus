//
//  NavigationRootView.swift
//  TestToDiscard
//
//  Created by Diptiranjan Rout on 11/03/25.
//

import SwiftUI

/// A root view container that manages navigation stack and deep linking
///
/// ## Example Usage
/// ```swift
/// // 1. Define your application routes
/// enum AppRoute: Route {
///     case home
///     case profile(id: UUID)
///     case settings
///
///     @ViewBuilder
///     func view(router: NavigationRouter<AppRoute>) -> some View {
///         switch self {
///         case .home: HomeView()
///         case .profile(let id): ProfileView(id: id)
///         case .settings: SettingsView()
///         }
///     }
/// }
///
/// // 2. Set up your app entry point
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             AppRootView<AppRoute> {
///                 HomeView() // Initial screen
///             }
///         }
///     }
/// }
///
/// // 3. Use in child views
/// struct HomeView: View {
///     @Environment(NavigationRouter<AppRoute>.self) private var router
///
///     var body: some View {
///         Button("View Settings") {
///             router.push(.settings) // Navigate using router
///         }
///     }
/// }
/// ```
///
/// - Important: The `MainRoute` generic parameter must conform to `Route` protocol,
///             which requires implementing `view(router:)` method.
public struct NavigationRootView<MainRoute: Route>: View {
    /// The navigation manager that handles routing and maintains stack state
    @State private var router: NavigationRouter<MainRoute>
    
    /// The root content view builder for the application
    private let rootView: () -> any View
    
    /// Creates an instance with a custom router
    /// - Parameters:
    ///   - router: Preconfigured navigation router instance
    ///   - rootView: View builder for the root content view
    @MainActor
    public init(
        router: NavigationRouter<MainRoute>,
        @ViewBuilder rootView: @escaping () -> some View
    ) {
        _router = State(wrappedValue: router)
        self.rootView = rootView
    }
    
    /// Creates an instance with a default router
    /// - Parameter rootView: View builder for the root content view
    @MainActor
    public init(
        @ViewBuilder rootView: @escaping () -> some View
    ) {
        let newRouter = NavigationRouter<MainRoute>()
        _router = State(wrappedValue: newRouter)
        self.rootView = rootView
    }
    
    public var body: some View {
        NavigationStack(path: $router.path) {
            // Type-erased wrapper to handle 'any View' closure
            AnyView(rootView())
                // Register navigation destinations for all route cases
                .navigationDestination(for: MainRoute.self) { route in
                    route.view(router: router)
                }
        }
        // Inject router into environment for child views
        .environment(router)
        // Handle universal links and deep URLs
        .onOpenURL { url in
            router.handleDeepLink(url)
        }
    }
}
