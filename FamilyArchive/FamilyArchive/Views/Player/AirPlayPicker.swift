import AVKit
import SwiftUI

/// 系统 AirPlay 选择器：中间按钮点按后弹出原生路由列表。
struct AirPlayPicker: UIViewRepresentable {
    @Binding var isPresented: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        guard isPresented else { return }
        uiView.subviews
            .compactMap { $0 as? UIButton }
            .first?
            .sendActions(for: .touchUpInside)
        DispatchQueue.main.async { isPresented = false }
    }
}
