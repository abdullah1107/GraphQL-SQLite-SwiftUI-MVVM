import SwiftUI

/// Switches between the splash, login and main screens based on `SessionViewModel.state`.
struct RootView: View {
    let container: AppContainer
    let session: SessionViewModel

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                ProgressView("Restoring session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loggedOut:
                LoginView(container: container, session: session)
                    .transition(.opacity)
            case .loggedIn(let user):
                MainTabView(container: container, session: session)
                    .id(user.id) // fresh view models for each login
                    .transition(.opacity)
            }
        }
        .animation(.default, value: session.state)
        .task { await session.restore() }
    }
}

#Preview {
    let container = AppContainer.preview()
    return RootView(container: container, session: SessionViewModel(authService: container.authService))
}
