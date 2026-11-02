import SwiftUI

/// 播放器设置：歌词源、翻译、粗体、字号缩放、模糊、拖动效果、歌词延迟。
struct PlayerSettingsView: View {
    @Environment(PlayerSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("歌词") {
                    Picker("默认歌词源", selection: Bindable(settings).source) {
                        ForEach(LyricsSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }

                    Toggle("中文翻译", isOn: Bindable(settings).showTranslation)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("歌词延迟")
                            Spacer()
                            Text(String(format: "%+.1f s", settings.latency))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Bindable(settings).latency,
                            in: -1...1,
                            step: 0.1
                        )
                    }
                }

                Section("显示") {
                    Toggle("粗体文本", isOn: Bindable(settings).boldText)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("字号缩放")
                            Spacer()
                            Text(String(format: "%.1fx", settings.fontScale))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Bindable(settings).fontScale, in: 0.8...1.4, step: 0.1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("模糊半径缩放")
                            Spacer()
                            Text(String(format: "%.1fx", settings.blurScale))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Bindable(settings).blurScale, in: 0...1.5, step: 0.1)
                    }

                    Toggle("拖动效果", isOn: Bindable(settings).pullEffect)
                }
            }
            .navigationTitle("播放器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
