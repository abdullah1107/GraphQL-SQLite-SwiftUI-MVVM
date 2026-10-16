import SwiftUI

/// AsyncImage with a placeholder and a failure icon.
struct RemoteImage: View {
    let url: String?
    var contentMode: ContentMode = .fit

    var body: some View {
        AsyncImage(url: url.flatMap { URL(string: $0) }) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
