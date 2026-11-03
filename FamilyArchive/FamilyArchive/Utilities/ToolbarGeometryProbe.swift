#if DEBUG
import SwiftUI
import UIKit

/// 仅 DEBUG：把系统 TabBar 的实际几何（含左右边距）打到控制台，
/// 用来把底部工具栏的 padding 对齐到系统真实数值，而不是靠截图估算。
struct ToolbarProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            Self.log()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private static func log() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            print("[ToolbarProbe] no window")
            return
        }

        let bounds = window.bounds
        print("[ToolbarProbe] window width=\(bounds.width) safeLeading=\(window.safeAreaInsets.leading) safeTrailing=\(window.safeAreaInsets.trailing)")

        var found = false
        func walk(_ view: UIView, depth: Int = 0) {
            if String(describing: type(of: view)).contains("TabBar") {
                let frame = view.convert(view.bounds, to: window)
                print(
                    "[ToolbarProbe] \(type(of: view)) frame=\(frame) "
                    + "minX=\(frame.minX) maxXInset=\(bounds.width - frame.maxX) "
                    + "height=\(frame.height) layoutMargins=\(view.layoutMargins)"
                )
                found = true
            }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        walk(window)
        if !found { print("[ToolbarProbe] no tab bar found") }
    }
}
#endif
