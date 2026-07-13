import ClawPetCore
import CoreGraphics
import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("ok: \(msg)") } else { failures += 1; print("FAIL: \(msg)") }
}
func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String) { check(a == b, "\(msg) [\(a) == \(b)]") }

// StateName
eq(StateName.flyLeft.rawValue, "fly-left", "flyLeft raw")
eq(StateName.allCases.count, 13, "13 states")
eq(StateName.parse("nonsense"), .hover, "parse fallback -> hover")
eq(StateName.parse("fly-right"), .flyRight, "parse fly-right")
check(StateName.cheer.isOneShot, "cheer is one-shot")
check(!StateName.working.isOneShot, "working loops")
check(!StateName.flyLeft.isOneShot, "flyLeft loops")

// PetManifest
let mj = #"{"id":"p","displayName":"P","spritesheetPath":"s.png","cell":{"w":192,"h":208},"states":[{"name":"hover","row":1,"frames":6,"durations":[280,140,140,180,180,320],"loop":true}]}"#
let m = try! JSONDecoder().decode(PetManifest.self, from: Data(mj.utf8))
eq(m.cell.h, 208, "cell h")
check(m.state(.hover)?.frames == 6, "hover frames == 6")
check(m.state(.singing) == nil, "singing absent")

// AtlasGeometry
let g = AtlasGeometry(cols: 8, rows: 13)
check(abs(g.rect(row: 0, frame: 0).width - 1.0/8) < 1e-9, "cell width 1/8")
check(abs(g.rect(row: 0, frame: 0).height - 1.0/13) < 1e-9, "cell height 1/13")
check(abs(g.rect(row: 1, frame: 2).minX - 2.0/8) < 1e-9, "cell x 2/8")
check(abs(g.rect(row: 1, frame: 2).minY - 1.0/13) < 1e-9, "cell y 1/13")

// PetStateMachine
var sm = PetStateMachine(); sm.setExternal(.working)
eq(sm.display, .working, "sm external working")
sm.setTyping(true); eq(sm.display, .typing, "typing > external")
sm.setDragging(.left); eq(sm.display, .flyLeft, "dragging > typing")
sm.setDragging(nil); eq(sm.display, .typing, "revert to typing")
var sm2 = PetStateMachine(); sm2.setExternal(.working); sm2.triggerInteraction(.twirl)
eq(sm2.display, .twirl, "interaction one-shot")
sm2.oneShotCompleted(); eq(sm2.display, .working, "revert after one-shot")
// drag must beat a lingering one-shot (the hover->wave bug fix)
var sm4 = PetStateMachine(); sm4.triggerInteraction(.wave)
eq(sm4.display, .wave, "one-shot shows when resting")
sm4.setDragging(.right); eq(sm4.display, .flyRight, "dragging beats one-shot")
sm4.setDragging(nil); eq(sm4.display, .wave, "one-shot resumes after drag")
check(PetStateMachine().isHoverIdle, "fresh machine is hover-idle")
var smC = PetStateMachine(); smC.setExternal(.waiting); smC.setExternal(.cheer); smC.oneShotCompleted()
eq(smC.display, .hover, "cheer settles base to hover (not stale waiting)")
var sm3 = PetStateMachine(); sm3.setExternal(.hover); sm3.setExternal(.cheer)
eq(sm3.display, .cheer, "external one-shot cheer")
sm3.oneShotCompleted(); eq(sm3.display, .hover, "base unchanged after external one-shot")

// FrameTicker
let t = FrameTicker(durations: [100,100,100], loop: true)
eq(t.frame(atElapsedMs: 0).index, 0, "ticker @0")
eq(t.frame(atElapsedMs: 150).index, 1, "ticker @150")
eq(t.frame(atElapsedMs: 300).index, 0, "ticker wraps @300")
check(!t.frame(atElapsedMs: 300).finished, "loop never finished")
let t2 = FrameTicker(durations: [100,100], loop: false)
eq(t2.frame(atElapsedMs: 250).index, 1, "one-shot last frame")
check(t2.frame(atElapsedMs: 250).finished, "one-shot finished")

// StateFileParser
eq(StateFileParser.parse(Data(#"{"state":"working","ts":1,"session":"a"}"#.utf8)), .working, "parse valid working")
eq(StateFileParser.parse(Data("garbage".utf8)), .hover, "parse corrupt -> hover")

// Version
eq(ClawPet.version, "0.1.0", "version")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
