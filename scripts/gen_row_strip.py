#!/usr/bin/env python3
"""M4 step 2: generate ONE animation row strip for the desktop pet, grounded on the base sprite.

Usage: gen_row_strip.py <state> <frames> [out.png]
Verifies feasibility of multi-frame consistency before committing to all 13 rows.
"""
import os, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from providers import edit_image
from grid_tools import grid_shape, make_layout_guide, slice_grid_to_row, CELL_W, CELL_H

WORKDIR = pathlib.Path(os.environ.get("CCPET_WORKDIR", "out"))
BASE = WORKDIR / "base.png"
ROWS = WORKDIR / "rows"

ROWS = AIPET / "rows"


# Per-state motion. AMP tier controls how much the pose may travel and how hard the
# scale-lock is phrased: "micro" (breathing), "mid" (task motion), "big" (whole-body action).
MOTION = {
    "hover":     ("micro", "a calm idle floating loop: hovers in place, wings beating softly, body bobbing up and down a few pixels, with one slow blink partway through. Wing-open/closed and the bob cycle back to the start so it loops seamlessly."),
    "working":   ("mid",   "a focused note-taking loop: he SITS at a small wooden desk, writing notes in an open notebook with a pen held in one hand, the other hand resting flat on the desk. He looks down at the notebook, occasionally pausing to think then writing again, small pen strokes visible across frames. Seated the whole time. Exactly two hands total: one writing with the pen, one resting on the desk. Wings relaxed behind the back."),
    "typing":    ("mid",   "a typing loop: a small laptop computer rests balanced on his left forearm, with his LEFT hand hidden behind/under the laptop and NOT visible. Only his RIGHT hand is visible, typing on the keyboard with fingers tapping up and down across frames. He looks down at the screen. IMPORTANT: exactly ONE visible hand (the right typing hand); the left hand is fully hidden behind the laptop; never draw a third hand or an extra hand near the laptop. No microphone. Wings flutter lightly."),
    "waiting":   ("mid",   "a patient thinking / waiting loop, UPRIGHT posture (not hunched): he rests one hand against his chin/cheek in a thoughtful pondering pose while looking toward the viewer, head tilting gently side to side, a small thought/music note floating above his head, wings fluttering softly, as if waiting and mulling things over. Exactly two hands: one at the chin, one relaxed at the side. No microphone."),
    "greet":     ("big",   "a SMOOTH CONTINUOUS greeting animation that reads as ONE flowing motion, each frame following from the previous (NOT disconnected poses). The sequence: (1) hovering low, just arriving, hand down; (2) rises a little, starting to lift one hand; (3) hand rising higher, beginning a wave, bright smile appearing; (4) hand raised up waving, big happy smile, a small musical note near the head; (5) waving hand at the top of its swing, cheerful; (6) hand lowering, settling into the calm resting hover pose. Continuous frame-to-frame progression. Exactly two arms and two hands, no microphone."),
    "cheer":     ("big",   "a one-shot happy celebration: a joyful little cheer, arms/mic raised, a small hop with sparkles, big smile, settling back down on the last frame."),
    "droop":     ("mid",   "a one-shot dejected reaction: shoulders slump, wings droop downward, head lowers with a sad disappointed expression, deflating over the frames."),
    "singing":   ("big",   "a one-shot singing performance: holds the microphone to his mouth and SINGS with the MOUTH CLEARLY OPENING AND CLOSING across the frames (wide open on some, smaller on others) so it reads as singing. EXPRESSION: happy and relaxed, eyebrows natural and raised in a cheerful way, absolutely NO frowning or furrowed/angry brows. Eyes are OPEN, bright and smiling in most frames; at most one or two frames may have softly closed eyes for emotion, not every frame. Body sways to the beat, a few musical notes float near the mic, wings shimmer."),
    "fly-left":  ("big",   "a leftward flight loop: the whole body leans and travels toward the LEFT, facing left. The two butterfly wings stay clearly attached to his UPPER BACK behind the shoulders and flap with a downstroke/upstroke cycle; the wings must NOT overlap or appear to grow out of his arms. Arms held naturally in front. Faint motion of hair and clothes. Must read as flying left. No foot-walking."),
    "fly-right": ("big",   "a rightward flight loop: the whole body leans and travels toward the RIGHT, facing right, wings flapping hard with a downstroke/upstroke cycle, a faint motion of hair and clothes. Must clearly read as flying right. No foot-walking."),
    "wave":      ("big",   "a one-shot friendly hello wave, NO microphone, both hands empty. CRITICAL ARM RULE: his LEFT arm and left hand hang straight DOWN at his left side, completely still and unmoving in EVERY frame (never raise the left arm). ONLY his RIGHT arm is raised up near his head and waves: across the frames the raised right forearm swings from left to right and back for a clear waving motion. The waving hand is the RIGHT hand in every single frame; do NOT switch which arm is raised between frames. Cheerful open smile. Exactly two arms and two hands, same length, well-formed. No microphone."),
    "twirl":     ("big",   "a one-shot mid-air spin: the character spins around once in place (front, side, back-ish, side, front), wings trailing the rotation, playful expression."),
    "hearts":    ("big",   "a SMOOTH CONTINUOUS affectionate animation that reads as ONE flowing motion, each frame following directly from the previous (NOT disconnected random poses). The sequence across the frames: (1) resting neutral like idle, hands down; (2) one hand starts rising; (3) one hand makes a single-hand finger-heart gesture (thumb and index crossed) up near the cheek, blushing; (4) BOTH hands come together above the chest forming a two-handed heart shape; (5) hold the two-hand heart, biggest smile, small pink hearts near the head; (6) hands lower back down toward the resting pose. Blushing happy throughout. STRICT: exactly two arms and two hands in every frame, no microphone, no extra limb."),
}

AMP_CLAUSE = {
    "micro": "SCALE LOCK: keep the character's apparent size and standing baseline identical across all frames; move only the pose subtly within the slot, never redraw the character larger or smaller.",
    "mid":   "SCALE LOCK: keep the character roughly the same apparent size and baseline across frames; the pose may move moderately within the slot but do not zoom or resize the character.",
    "big":   "MOTION FREEDOM: the pose may move boldly within the slot to sell the action, but keep the character the SAME drawn size (do not zoom the camera in or out); keep the whole body inside its slot without clipping.",
}


def build_prompt(state: str, frames: int, cols: int, rows: int) -> str:
    amp, motion = MOTION[state]
    return (
        f"Create a 2D game sprite animation sheet for one animation state: EXACTLY {frames} full-body "
        f"frames arranged in a {cols}-column by {rows}-row grid, filled left-to-right then top-to-bottom. "
        "TWO REFERENCE IMAGES ARE ATTACHED. Image 1 is the CANONICAL CHARACTER: copy its identity exactly. "
        "Image 2 is a LAYOUT GUIDE: use it ONLY for the number of slots, their spacing, and centering the "
        "character inside each slot. DO NOT draw the guide's grid lines, numbers, borders or margins. "
        "IDENTITY LOCK: the same character in every frame, identical pixel art style, face, hair, outfit, "
        "colors and wings. Do not redesign or restyle between frames. "
        "ANATOMY: correct human anatomy in every frame: exactly one head, exactly two arms and two hands, "
        "five fingers per hand, no extra hands, no duplicated or fused limbs, no malformed lumpy hands. "
        "The butterfly wings attach ONLY at the upper back behind the shoulders, never on the arms. "
        f"{AMP_CLAUSE[amp]} "
        "One centered complete character per slot, no overlap, no clipping, no empty slot. "
        f"THE ANIMATION: {motion} "
        "STYLE: authentic MapleStory-style pixel art, crisp hard-edged pixels, limited palette, sharp 1px "
        "outline, no anti-aliasing, no blur, no gradients. "
        "BACKGROUND: flat pure chroma-key green #00FF00 across the entire image. The character, its outfit, "
        "wings and props must contain NO green that resembles the chroma key. No shadow, no floor, no scenery, "
        "no text, no frame numbers, no visible grid lines, no borders or dividers between slots."
    )




def main() -> int:
    state = sys.argv[1] if len(sys.argv) > 1 else "hover"
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    if state not in MOTION:
        raise KeyError(f"no motion for state '{state}'; known: {sorted(MOTION)}")

    ROWS.mkdir(parents=True, exist_ok=True)
    out = sys.argv[3] if len(sys.argv) > 3 else str(ROWS / f"{state}.png")

    guide = ROWS / f"_guide_{frames}.png"
    make_layout_guide(frames, guide)
    print(f"[1/2] layout guide {cols}x{rows} -> {guide}", flush=True)
    raw = str(ROWS / f"_raw_{state}.png")
    print(f"[2/2] generating '{state}' grid ({frames}f, {cols}x{rows}) via provider={os.environ.get('CCPET_PROVIDER','fal')}", flush=True)
    edit_image(build_prompt(state, frames, cols, rows), [str(BASE), str(guide)],
               size={"width": cols * CELL_W * 2, "height": rows * CELL_H * 2}, out_path=raw)
    slice_grid_to_row(pathlib.Path(raw), frames, pathlib.Path(out))
    print(f"DONE: {out}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
