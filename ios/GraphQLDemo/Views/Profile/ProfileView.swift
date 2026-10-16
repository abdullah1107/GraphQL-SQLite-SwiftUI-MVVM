import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    init(container: AppContainer, session: SessionViewModel) {
        _viewModel = State(initialValue: ProfileViewModel(
            authService: container.authService,
            syncService: container.syncService,
            settings: container.settings,
            session: session
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                if let user = viewModel.user {
                    Section { header(user) }
                }

                Section {
                    if viewModel.syncStatus.isEmpty {
                        Text("Not synced yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.syncStatus) { row in
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                Text("\(row.count) rows")
                                if let date = row.syncedDate {
                                    Text(date, format: .relative(presentation: .named))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            Label(row.entity.capitalized, systemImage: row.entity == "products" ? "bag" : "cart")
                        }
                    }

                    Button {
                        Task { await viewModel.syncNow() }
                    } label: {
                        HStack {
                            Label("Sync from DummyJSON now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if viewModel.isSyncing { ProgressView() }
                        }
                    }
                    .disabled(viewModel.isSyncing)
                } header: {
                    Text("Server database (SQLite)")
                } footer: {
                    if let message = viewModel.message {
                        Text(message).foregroundStyle(.green)
                    } else if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("Runs `mutation SyncAll`: the server downloads /products and /carts and upserts them into its database.")
                    }
                }

                Section("Connection") {
                    LabeledContent("GraphQL endpoint", value: viewModel.endpoint.absoluteString)
                        .font(.footnote)
                }

                Section {
                    Button("Log out", role: .destructive) {
                        Task { await viewModel.logout() }
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    private func header(_ user: User) -> some View {
        HStack(spacing: 16) {
            RemoteImage(url: user.image, contentMode: .fill)
                .frame(width: 64, height: 64)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName).font(.title3.bold())
                Text("@\(user.username)").foregroundStyle(.secondary)
                if let email = user.email {
                    Text(email).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = AppContainer.preview()
    let session = SessionViewModel(authService: container.authService)
    session.didLogin(PreviewData.user)
    return ProfileView(container: container, session: session)
}
