import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @State private var showServerSettings = false
    private let session: SessionViewModel

    init(container: AppContainer, session: SessionViewModel) {
        self.session = session
        _viewModel = State(initialValue: LoginViewModel(
            authService: container.authService,
            settings: container.settings,
            session: session
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                        Text("GraphQL Demo")
                            .font(.title.bold())
                        Text("DummyJSON → GraphQL → SwiftUI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                if let notice = session.notice {
                    Section {
                        Label(notice, systemImage: "info.circle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Account") {
                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .onSubmit { Task { await viewModel.login() } }
                }

                Section {
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Log in").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                } footer: {
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("Demo account: emilys / emilyspass (any user from dummyjson.com/users works).")
                    }
                }

                Section {
                    DisclosureGroup("Server", isExpanded: $showServerSettings) {
                        TextField("GraphQL endpoint", text: $viewModel.serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.callout.monospaced())
                        Text("Simulator: http://localhost:4000/ · iPhone: http://<your-Mac-IP>:4000/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    return LoginView(container: container, session: SessionViewModel(authService: container.authService))
}
