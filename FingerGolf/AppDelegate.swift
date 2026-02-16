import SwiftUI

@main
struct FingerGolfApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .statusBarHidden()
        }
    }
}

/// Wrapper that shows a loading spinner before ContentView initializes.
/// ContentView's @StateObject GameCoordinator is created when ContentView first appears,
/// which happens after the loading screen is already visible — preventing a frozen first frame.
struct AppRootView: View {
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                ContentView()
                    .transition(.opacity)
            } else {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isReady)
        .task {
            // Yield twice to ensure LoadingView renders and the spinner animates
            await Task.yield()
            await Task.yield()
            isReady = true
        }
    }
}
