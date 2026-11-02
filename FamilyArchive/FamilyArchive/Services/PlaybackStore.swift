import AVFoundation
import Foundation
import Observation

/// 播放条与播放器共享的一条队列。
struct PlaybackItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case audio
        case video
    }

    let id: String
    let title: String
    let subtitle: String
    let artwork: Data?
    let fileURL: URL?
    let kind: Kind
    let lyricsText: String
}

@Observable
@MainActor
final class PlaybackStore {
    private(set) var queue: [PlaybackItem] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    var current: PlaybackItem? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    var lyrics: [LyricLine] {
        guard let current else { return [] }
        return LRCParser.parse(current.lyricsText)
    }

    var currentLyricIndex: Int? {
        LRCParser.currentIndex(in: lyrics, at: currentTime)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    // MARK: - 队列

    func replaceQueue(_ items: [PlaybackItem], startAt startIndex: Int = 0) {
        queue = items
        index = items.isEmpty ? 0 : min(max(startIndex, 0), items.count - 1)
        loadCurrent(autoPlay: false)
    }

    func play(_ items: [PlaybackItem], startAt startIndex: Int = 0) {
        replaceQueue(items, startAt: startIndex)
        play()
    }

    func next() {
        guard !queue.isEmpty else { return }
        index = (index + 1) % queue.count
        loadCurrent(autoPlay: isPlaying)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        index = (index - 1 + queue.count) % queue.count
        loadCurrent(autoPlay: isPlaying)
    }

    func select(_ newIndex: Int) {
        guard queue.indices.contains(newIndex) else { return }
        index = newIndex
        loadCurrent(autoPlay: isPlaying)
    }

    // MARK: - 播放控制

    func play() {
        guard current != nil else { return }
        if player == nil { loadCurrent(autoPlay: false) }
        player?.play()
        isPlaying = player?.isPlaying ?? false
        startTicker()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to time: Double) {
        guard let player else {
            currentTime = max(0, time)
            return
        }
        player.currentTime = min(max(time, 0), player.duration)
        currentTime = player.currentTime
    }

    func seek(toProgress value: Double) {
        guard duration > 0 else { return }
        seek(to: duration * min(max(value, 0), 1))
    }

    // MARK: - 内部

    private func loadCurrent(autoPlay: Bool) {
        stopTicker()
        player?.stop()
        player = nil
        currentTime = 0
        duration = 0
        isPlaying = false

        guard let current, current.kind == .audio, let url = current.fileURL else { return }
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.prepareToPlay()
        player = newPlayer
        duration = newPlayer.duration

        if autoPlay {
            newPlayer.play()
            isPlaying = true
            startTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        if !player.isPlaying, isPlaying {
            isPlaying = false
            if currentTime >= player.duration - 0.25 {
                next()
            }
        }
    }
}
