import SwiftUI

@main
struct GraphQLDemoApp: App {
    private let container: AppContainer
    @State private var session: SessionViewModel

    init() {
        let container = AppContainer.live()
        self.container = container
        _session = State(initialValue: SessionViewModel(authService: container.authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container, session: session)
        }
    }
}
