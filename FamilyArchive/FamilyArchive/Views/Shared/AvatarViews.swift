import SwiftUI
import UIKit

struct RemoteAvatarView: View {
    let urlString: String
    var systemImage: String = "person.crop.circle.fill"
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary, in: Circle())
    }
}

struct DataImageView: View {
    let data: Data?
    var systemImage: String = "photo"
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}
