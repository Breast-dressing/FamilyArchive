import LinkPresentation
import SwiftUI
import UIKit

/// Presents the system share sheet directly from the hosting controller,
/// without nesting it in a SwiftUI sheet.
struct FamilySharePresenter: UIViewControllerRepresentable {
    @Binding var payload: FamilySharePayload?
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> SharePresenterController {
        let controller = SharePresenterController()
        controller.onFinish = onFinish
        return controller
    }

    func updateUIViewController(_ controller: SharePresenterController, context: Context) {
        controller.onFinish = onFinish
        if let payload {
            controller.presentIfNeeded(payload)
        }
    }
}

final class SharePresenterController: UIViewController {
    var onFinish: (() -> Void)?
    private var pendingPayload: FamilySharePayload?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPendingIfPossible()
    }

    func presentIfNeeded(_ payload: FamilySharePayload) {
        pendingPayload = payload
        presentPendingIfPossible()
    }

    private func presentPendingIfPossible() {
        guard let payload = pendingPayload,
              view.window != nil,
              presentedViewController == nil else { return }
        pendingPayload = nil

        let controller = FamilyShareSheet.makeController(payload: payload) { [weak self] in
            self?.onFinish?()
        }
        present(controller, animated: true)
    }
}

enum FamilyShareSheet {
    static func makeController(
        payload: FamilySharePayload,
        onFinish: @escaping () -> Void
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [FamilyShareItemSource(payload: payload)],
            applicationActivities: [
                FamilyCopyActivity(payload: payload),
                FamilyImageActivity(payload: payload)
            ]
        )
        controller.excludedActivityTypes = [.copyToPasteboard]
        controller.completionWithItemsHandler = { _, _, _, _ in
            onFinish()
        }
        return controller
    }
}

final class FamilyShareItemSource: NSObject, UIActivityItemSource {
    private let payload: FamilySharePayload

    init(payload: FamilySharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        "\(payload.familyName)\n族长：\(payload.leaderName)\n\(payload.period)"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.copyText
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "\(payload.familyName) · 族长 \(payload.leaderName)"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "\(payload.familyName) · 族长 \(payload.leaderName)"
        metadata.originalURL = payload.familyURL

        if let avatar = payload.avatar {
            metadata.iconProvider = NSItemProvider(object: avatar)
            metadata.imageProvider = NSItemProvider(object: avatar)
        } else {
            let configuration = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            if let placeholder = UIImage(
                systemName: "person.3.fill",
                withConfiguration: configuration
            ) {
                metadata.iconProvider = NSItemProvider(object: placeholder)
            }
        }

        return metadata
    }
}

final class FamilyCopyActivity: UIActivity {
    static let activityType = UIActivity.ActivityType(
        "com.example.FamilyArchive.copyHonor"
    )

    private let payload: FamilySharePayload

    init(payload: FamilySharePayload) {
        self.payload = payload
    }

    override var activityType: UIActivity.ActivityType? {
        Self.activityType
    }

    override var activityTitle: String? {
        "拷贝"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "doc.on.doc")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func perform() {
        UIPasteboard.general.string = payload.copyText
        activityDidFinish(true)
    }
}

final class FamilyImageActivity: UIActivity {
    static let activityType = UIActivity.ActivityType(
        "com.example.FamilyArchive.exportImage"
    )

    private let payload: FamilySharePayload

    init(payload: FamilySharePayload) {
        self.payload = payload
    }

    override var activityType: UIActivity.ActivityType? {
        Self.activityType
    }

    override var activityTitle: String? {
        "图片"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "photo")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func perform() {
        Task { @MainActor in
            guard let image = FamilyHonorImageRenderer.image(for: payload) else {
                activityDidFinish(false)
                return
            }
            guard let presenter = UIApplication.shared.topViewController else {
                activityDidFinish(false)
                return
            }

            presenter.dismiss(animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    let imageShare = UIActivityViewController(
                        activityItems: [image],
                        applicationActivities: nil
                    )
                    UIApplication.shared.topViewController?
                        .present(imageShare, animated: true)
                    self.activityDidFinish(true)
                }
            }
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
