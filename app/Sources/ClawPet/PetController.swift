import AppKit
import ClawPetCore

final class PetController {
    let manifest: PetManifest
    var machine = PetStateMachine()
    private let view: PetView
    private let animator = FrameAnimator()

    init(petDir: String) {
        let dir = petDir as NSString
        let mData = try! Data(contentsOf: URL(fileURLWithPath: dir.appendingPathComponent("pet.json")))
        manifest = try! JSONDecoder().decode(PetManifest.self, from: mData)
        let imgPath = dir.appendingPathComponent(manifest.spritesheetPath)
        let cg = SpriteImage.load(imgPath) ?? SpriteImage.magentaPlaceholder()
        let geo = AtlasGeometry(cols: 8, rows: manifest.states.count)
        view = PetView(image: cg, geometry: geo)
        animator.onFrame = { [weak self] r, f in self?.view.show(row: r, frame: f) }
        animator.onOneShotDone = { [weak self] in self?.machine.oneShotCompleted(); self?.apply() }
        apply()
    }
    var contentView: NSView { view }

    /// Re-resolve display state and (re)start its animation.
    func apply() {
        let name = machine.display
        let spec = manifest.state(name) ?? manifest.state(.hover)!
        animator.play(spec: spec)
    }
}
