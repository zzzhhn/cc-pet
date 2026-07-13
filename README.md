# cc-pet

**Turn one photo into a native macOS desktop pet that mirrors what Claude Code is doing.**

A floating pixel-art sprite lives on your screen and reacts in real time: it works while
Claude works, waits when Claude needs your approval, cheers (or sings, for long tasks) when a
turn finishes, droops when a tool errors, types alongside you, and flies when you drag it.

English · [中文](README.zh-CN.md) · **[LESSONS.md](LESSONS.md)** (the hard-won debugging journey)

---

## What's in here

| Piece | What it is |
|-------|-----------|
| `app/` | A native Swift app (SwiftPM). `ClawPetCore` is pure and unit-tested; `ClawPet` is a transparent, floating, always-on-top AppKit window that renders a sprite atlas. |
| `hooks/` | `pet-state` — a tiny script that reads Claude Code hook JSON on stdin and writes the pet's current state to a file the app polls. |
| `scripts/` | The photo → atlas art pipeline, plus install/bundle/QA tooling. |
| `pets/placeholder/` | A generated placeholder atlas (colored blocks) so the mechanism runs before you make real art. |

## Quick start (mechanism, with placeholder art)

```bash
cd app
swift run ClawPet          # a floating pet appears; 🧚 menubar to quit
swift run ClawPetTests     # core assertion suite (no Xcode / no XCTest needed)
```

Install persistently and wire it to Claude Code:

```bash
scripts/install.sh                 # build release, install binary + hook + placeholder pet
# merge hooks/settings-hooks-snippet.json into ~/.claude/settings.json
# grant Input Monitoring permission when prompted (enables the `typing` state)
```

## The 13 states and their triggers

**From Claude Code** (hook → `pet-state` → `~/.claude/pet/state.json`, polled by the app):

| State | Trigger |
|-------|---------|
| greet | `SessionStart` (also auto-launches the app) |
| working | `UserPromptSubmit` / `PreToolUse` / `PostToolUse` |
| waiting | `Notification` (permission prompt) |
| droop | `PostToolUse` with `isError: true` |
| cheer | `Stop` after a normal turn |
| singing | `Stop` after a long turn (≥ 8 tool calls or ≥ 120 s) — an easter egg |
| hover | idle default (Claude done, an `idle_prompt` notification, or after a one-shot settles) |

**From the mouse / keyboard / timer:** fly-left/right (drag), twirl (double-click),
hearts (click), typing (you type, needs Input Monitoring), wave (random, 30 s @ 50 %, only when idle).

Priority: **drag > one-shot gesture > typing > Claude-Code state > hover.**

## Make your own pet from a photo

```bash
export FAL_KEY=...            # see .env.example; provider is pluggable (scripts/providers.py)
python3 scripts/gen_base_sprite.py my-photo.png            # photo -> base sprite
python3 scripts/gen_row_strip.py hover 6                   # generate one animation row (grid, green-screen)
python3 scripts/reslice.py out/rows pets/mypet/pet.json    # segment + re-anchor into clean cells
python3 scripts/compose_atlas.py out/rows pets/mypet       # stack rows -> spritesheet.png
python3 scripts/check_clipping.py pets/mypet pets/mypet/pet.json   # QA: 0 frames may touch a cell edge
```

The **provider is pluggable** — `scripts/providers.py` defines a one-method adapter
(`edit_image`). The reference implementation is fal.ai's `gpt-image-2/edit`; swap in OpenAI,
OpenRouter, Gemini, or a local model by implementing that one function.

## The atlas contract

A `1536 × (rows·208)` PNG, 8 columns of `192×208` cells, one state per row, transparent
background. Frame counts and durations live in `pet.json` (single source of truth). Adapted
from OpenAI's `hatch-pet` — see [NOTICE](NOTICE).

## Why this was hard

The pipeline looks simple; making it robust was not. Sprite segmentation, the fal 3:1 canvas
cap, the FSEvents-vs-atomic-rename bug, the hook-that-hangs-Claude-Code, drift, clipping,
anatomy defects — each is written up in **[LESSONS.md](LESSONS.md)**. Read it before changing
the pipeline; most "obvious" approaches were tried and failed for documented reasons.

## Requirements

macOS 14+, Swift toolchain (Command Line Tools is enough — no Xcode). Python 3 + Pillow +
numpy for the art pipeline. Apache-2.0 licensed.
