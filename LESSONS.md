# LESSONS — what actually broke, and why

This project reached a working state through many rounds of debugging. Almost every
"obvious" first approach failed for a concrete, reproducible reason. This file is the
map of those failures so you don't re-walk them. Read it before changing the pipeline.

Format per lesson: **symptom → root cause → fix.**

---

## A. Generating the sprite art (fal.ai gpt-image-2)

**1. Can't generate a wide animation strip.**
Symptom: the API rejects an 8:1 canvas with `aspect ratio ... exceeds the maximum supported 3:1`.
Root cause: fal caps the output aspect ratio at 3:1.
Fix: generate frames as a **2×N grid** (e.g. 3×2 for 6 frames), then re-flow to one row. Providers
without this cap (OpenAI native) can use a single wide strip.

**2. "Big head, small body" is ignored; proportions come out wrong.**
Root cause: qualitative prompt words carry no weight against the model's prior.
Fix: **quantify** — "about 2.5 heads tall", "limbs short and stubby, all four of equal scale". Constrain
*all* limbs, not just legs: constraining only legs produced gibbon-length arms (the model compensated
on the unconstrained dimension).

**3. "Detailed pixel art" produces a smooth illustration that merely looks retro.**
Fix: specify a grid ("64×64 pixel art sprite"), a limited palette ("~24 colors"), "hard edges, 1px
outline, no anti-aliasing", and an era anchor ("16-bit SNES JRPG sprite"). Generate small, scale with
nearest-neighbor.

**4. A gesture + a held prop + two hands = anatomy defects.**
Symptom: two microphones appear; a third hand sprouts near the laptop.
Root cause: hand↔object↔gesture is the model's highest-defect combination.
Fix: **minimize visible hands** — hide one hand *behind* the object (only one hand visible), or drop the
prop for that state. Also lock which hand holds the prop; the model swaps left/right between frames,
which reads as teleporting.

**5. Animation looks like random stills, not motion.**
Root cause: "do a wave" yields independent poses per cell.
Fix: describe the motion as a **frame-by-frame sequence** ("(1) resting, (2) hand rising, (3) …, (6)
settling"), and state that each frame follows continuously from the previous.

**6. Default expressions are wrong (frowning, always-closed eyes).**
Fix: specify "relaxed/raised brows, no furrow", "eyes open and bright in most frames, softly closed in at
most one or two".

## B. Cutting the grid into an atlas (the hardest part)

**7. Frames drift / the character "teleports" within its cell.**
Root cause: rigid geometric slicing (crop every 192px) assumes the model placed each character on the grid.
It doesn't — a character can sit half a cell off-center.
Fix: **segment by connected components over the whole image**, take the N largest blobs as character seeds,
order them row-major, attach small blobs (notes/hearts) to the nearest seed, and re-center each character
into a clean cell. This is grid-alignment-agnostic. (Calibrated to OpenAI hatch-pet's approach.)

**8. Part of the character is missing ("incomplete crop"), but an edge-clip detector reports nothing.**
Root cause: a detached wing/limb component was *dropped* during segmentation, or a per-cell search region
was too narrow and cut the character before cropping. A missing part isn't at the edge — it's gone — so an
edge detector can't see it.
Fix: whole-grid seeding (lesson 7) captures the full character wherever it is. Verify with **two** QA
scripts: an edge-clip check (content must not touch the cell border) *and* completeness (captured area ≈
seed area).

**9. White background gets keyed out together with the character's white clothes.**
Fix: generate on **chroma green (#00FF00)**, never white, and forbid near-chroma colors in the character.

**10. Text like "6 equal cells" doesn't produce 6 equal cells.**
Fix: give the model a **layout-guide image** (a drawn grid with numbered cells) as a second reference, and
tell it to copy the layout but not draw the guide. A visual constraint beats a textual one.

**11. Wings clip at the cell edge; or the character sits off-center because of far satellites.**
Fix: anchor scaling and centering on the **body bounding box** (seed + adjoining wing pieces), not the
union with far satellites. Only small, far satellites (notes/sparkles) may extend past the cell edge.

**12. Eyeballing a contact sheet misses defects.**
Root cause: a downscaled contact sheet hides extra hands and small clips.
Fix: inspect each frame at **native resolution, per cell**, and — better — replace subjective review with
**quantifiable assertions** (a `check_clipping.py` that flags any frame whose content touches the border).
Quantifiable QA beats vibes.

## C. The Swift app's behavior

**13. Dragging freezes on one frame instead of animating the flight.**
Root cause: calling `apply()` on every mouse-drag event restarted the animation timer to frame 0.
Fix: only re-apply when the drag *direction changes*.

**14. Reversing drag direction is laggy.**
Root cause: direction computed from cumulative offset since the grab point — you had to drag back past the
origin to flip.
Fix: compute direction from **instantaneous** motion between successive events.

**15. Dragging shows "wave" instead of "fly".**
Root cause: a lingering one-shot gesture (hover-triggered wave) outranked dragging in the state machine.
Fix: **dragging is top priority** — it beats any one-shot.

**16. When idle, the pet stays "waiting" (or "working"), never returns to hover.**
Root cause: two bugs. (a) After `Stop`→cheer, the base loop reverted to a stale `working`/`waiting`.
(b) Claude fires an `idle_prompt` notification when merely idle, which was mapped to `waiting`.
Fix: greet/cheer/singing settle the base loop to **hover**; map `idle_prompt` notifications to hover, and
only `permission_prompt` to waiting.

**17. The random wave interrupts other states.**
Fix: fire the 30s random wave **only when the display is hover** (true idle), never over working/typing/fly.

## D. Hooks and IPC (the subtle ones)

**18. singing and droop never trigger from real Claude Code.**
Root cause: Claude Code passes hook data as **JSON on stdin**, not positional args. The script read `$2/$3`
for tool count → always 0 → always cheer, never singing; and never saw `isError` → never droop.
Fix: parse stdin JSON (`hook_event_name`, `session_id`, `isError`); count tool calls **per session** on
`PreToolUse` for the singing threshold.

**19. `claude --resume` hangs at loading after wiring auto-launch.**
Root cause: the SessionStart hook spawned the GUI app as a **hook child** (`nohup … &`); the app inherited
the hook's file descriptors / process group, so Claude Code waited on it forever.
Fix: launch via **`open -g App.app`** (LaunchServices) — launchd starts the app in its own context,
inheriting nothing, and `open` returns in ~0.2s.

**20. The app never updates after the first state change (the worst one).**
Symptom: the state file provably reached `hover`, but the pet stayed on an old state.
Root cause: the writer is atomic (`mktemp` + `mv -f`), which **replaces the file's inode**. An FSEvents
watch bound to the old inode goes deaf after the first replace — the path still exists (a new inode), so a
"is it gone?" re-arm check never fires.
Fix: **poll** the tiny state file (~5×/sec, gated on mtime) instead of watching an inode. Atomic writers and
inode-watchers are fundamentally incompatible.

## E. Process

**21. No Xcode installed → no XCTest.**
Fix: write the core tests as a **plain executable** (`swift run ClawPetTests`) that asserts and exits
non-zero on failure. Pure value-type logic needs no test framework.

**22. Instrument the boundary before guessing.**
Bug 20 was cracked by adding a one-line write-log to the hook, which proved the *hook* was correct and the
*app* was deaf — collapsing hours of speculation into one read. When a multi-component system misbehaves,
log what crosses each boundary first, then look where the evidence points.
