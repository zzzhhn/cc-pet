import AppKit
import ClawPetCore

final class FrameAnimator {
    private var timer: Timer?
    private var ticker = FrameTicker(durations: [1], loop: true)
    private var row = 0
    private var start = Date()
    var onFrame: ((Int, Int) -> Void)?
    var onOneShotDone: (() -> Void)?

    func play(spec: StateSpec) {
        row = spec.row
        ticker = FrameTicker(durations: spec.durations, loop: spec.loop)
        start = Date()
        if timer == nil {
            let t = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }
    private func tick() {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let (idx, finished) = ticker.frame(atElapsedMs: ms)
        onFrame?(row, idx)
        if finished { onOneShotDone?() }
    }
}
