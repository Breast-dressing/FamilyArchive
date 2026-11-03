import SwiftUI
import UIKit

/// 播放条里需要参与对齐核对的子视图。
enum PlaybackBarPart {
    case capsule
    case plus
}

#if DEBUG
/// 底部浮动播放条的实测框架，由 `NowPlayingMiniBar` 在布局后写入。
/// 只用于对齐诊断：CI 模拟器把这里的值与系统 TabBar 的框架一起导出，
/// 避免再靠截图目测估算左右边距。
@MainActor
final class PlaybackBarGeometry {
    static let shared = PlaybackBarGeometry()

    var capsuleFrame: CGRect = .zero
    var plusFrame: CGRect = .zero

    func record(_ frame: CGRect, part: PlaybackBarPart) {
        switch part {
        case .capsule: capsuleFrame = frame
        case .plus: plusFrame = frame
        }
    }
}
#endif

extension View {
    /// 把播放条子视图在屏幕坐标系里的真实框架记录下来，供 DEBUG 探针导出。
    func recordPlaybackFrame(_ part: PlaybackBarPart) -> some View {
        #if DEBUG
        return onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            PlaybackBarGeometry.shared.record(frame, part: part)
        }
        #else
        return self
        #endif
    }
}

#if DEBUG
/// 把窗口里与底部 TabView 相关的视图框架导出为 JSON，写入 App 的 Documents，
/// 并（可选）在窗口上画参考线截图。只在 DEBUG 生效。
struct BottomChromeProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = ProbeView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class ProbeView: UIView {
    private var lastCapture: Date?
    private var guideOverlay: UIView?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // 等 SwiftUI 完成布局与安全区计算，再读系统 TabBar 的最终几何。
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.capture()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            self?.capture()
        }
    }

    private func capture() {
        guard let window, window.windowScene != nil else { return }
        let now = Date()
        if let lastCapture, now.timeIntervalSince(lastCapture) < 1.5 { return }
        lastCapture = now

        let playback = PlaybackBarGeometry.shared
        var payload: [String: Any] = [
            "capturedAt": ISO8601DateFormatter().string(from: now),
        ]

        let screen = window.screen
        payload["screen"] = [
            "bounds": dict(screen.bounds),
            "nativeScale": Double(screen.nativeScale),
            "scale": Double(screen.scale),
        ]
        payload["window"] = [
            "bounds": dict(window.bounds),
            "safeAreaInsets": dict(window.safeAreaInsets),
            "frame": dict(window.frame),
        ]
        payload["sizeClass"] = window.traitCollection.horizontalSizeClass == .regular
            ? "regular" : "compact"
        payload["playback"] = [
            "capsule": dict(playback.capsuleFrame),
            "plus": dict(playback.plusFrame),
            "capsuleLeadingInset": Double(playback.capsuleFrame.minX),
            "plusTrailingInset": Double(window.bounds.width - playback.plusFrame.maxX),
        ]

        var tabBars: [[String: Any]] = []
        var bottomViews: [[String: Any]] = []
        let cut = window.bounds.height - 260

        func walk(_ view: UIView, depth: Int) {
            let frame = view.convert(view.bounds, to: window)
            if view is UITabBar {
                tabBars.append(describe(view, depth: depth, window: window))
            }
            if depth <= 45, !view.isHidden, view.alpha > 0.01, frame.minY >= cut, frame.width > 2, frame.height > 2 {
                bottomViews.append([
                    "depth": depth,
                    "class": String(describing: type(of: view)),
                    "frame": dict(frame),
                    "alpha": Double(view.alpha),
                    "identifier": view.accessibilityIdentifier ?? "",
                    "label": view.accessibilityLabel ?? "",
                    "isControl": view is UIControl,
                ])
            }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        walk(window, depth: 0)
        payload["tabBars"] = tabBars
        payload["bottomViews"] = bottomViews

        write(payload, to: window)
        if ProcessInfo.processInfo.arguments.contains("-UIPreviewGuides") {
            drawGuides(in: window)
        }
    }

    private func describe(_ view: UIView, depth: Int, window: UIView) -> [String: Any] {
        var item: [String: Any] = [
            "depth": depth,
            "class": String(describing: type(of: view)),
            "frame": dict(view.convert(view.bounds, to: window)),
            "bounds": dict(view.bounds),
            "layoutMargins": dict(view.layoutMargins),
            "safeAreaInsets": dict(view.safeAreaInsets),
            "alpha": Double(view.alpha),
            "hidden": view.isHidden,
        ]
        item["subviews"] = view.subviews.map { describe($0, depth: depth + 1, window: window) }
        return item
    }

    private func dict(_ rect: CGRect) -> [String: Double] {
        [
            "x": Double(rect.origin.x),
            "y": Double(rect.origin.y),
            "width": Double(rect.width),
            "height": Double(rect.height),
        ]
    }

    private func dict(_ insets: UIEdgeInsets) -> [String: Double] {
        [
            "top": Double(insets.top),
            "left": Double(insets.left),
            "bottom": Double(insets.bottom),
            "right": Double(insets.right),
        ]
    }

    private func write(_ payload: [String: Any], to window: UIView) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }
        let url = documents.appendingPathComponent("BottomChromeGeometry.json")
        try? data.write(to: url)
        let text = String(data: data, encoding: .utf8) ?? ""
        NSLog("[BottomChromeProbe] %@", text)
    }

    private func drawGuides(in window: UIView) {
        guideOverlay?.removeFromSuperview()
        let overlay = GuideOverlayView(frame: window.bounds)
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        overlay.capsuleFrame = PlaybackBarGeometry.shared.capsuleFrame
        overlay.plusFrame = PlaybackBarGeometry.shared.plusFrame
        overlay.tabBarFrames = tabBarFrames(in: window)
        window.addSubview(overlay)
        guideOverlay = overlay
    }

    private func tabBarFrames(in window: UIView) -> [CGRect] {
        var frames: [CGRect] = []
        func walk(_ view: UIView) {
            if view is UITabBar {
                frames.append(view.convert(view.bounds, to: window))
                frames.append(contentsOf: view.subviews
                    .filter { $0.bounds.width > 120 && $0.bounds.height > 20 }
                    .map { $0.convert($0.bounds, to: window) })
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(window)
        return frames
    }
}

/// 参考线：红色 = 系统 TabBar 相关框架，绿色 = 播放条胶囊，蓝色 = ＋ 按钮。
private final class GuideOverlayView: UIView {
    var capsuleFrame: CGRect = .zero
    var plusFrame: CGRect = .zero
    var tabBarFrames: [CGRect] = []

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        func line(_ x: CGFloat, _ color: UIColor, _ width: CGFloat) {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
            context.strokePath()
        }

        for frame in tabBarFrames {
            line(frame.minX, .systemRed, 1)
            line(frame.maxX, .systemRed, 1)
        }
        if capsuleFrame != .zero {
            line(capsuleFrame.minX, .systemGreen, 1.5)
            line(capsuleFrame.maxX, .systemGreen, 1)
        }
        if plusFrame != .zero {
            line(plusFrame.minX, .systemBlue, 1)
            line(plusFrame.maxX, .systemBlue, 1.5)
        }
    }
}
#endif
