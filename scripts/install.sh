#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PET="${HOME}/.claude/pet"
mkdir -p "${PET}/bin" "${PET}/pets"
( cd "${ROOT}/app" && swift build -c release )
cp "${ROOT}/app/.build/release/ClawPet" "${PET}/bin/ClawPet"
# also install the .app bundle so the SessionStart hook can launch via LaunchServices
bash "${ROOT}/scripts/bundle_app.sh" >/dev/null 2>&1 || true
[ -d "${ROOT}/ClawPet.app" ] && ditto "${ROOT}/ClawPet.app" "${PET}/ClawPet.app"
install -m 0755 "${ROOT}/hooks/pet-state" "${PET}/bin/pet-state"
# Refresh the placeholder pet in place (no recursive delete).
mkdir -p "${PET}/pets/placeholder"
cp "${ROOT}/pets/placeholder/pet.json" "${PET}/pets/placeholder/pet.json"
cp "${ROOT}/pets/placeholder/spritesheet.png" "${PET}/pets/placeholder/spritesheet.png"
echo "Installed to ${PET}"
echo "Next:"
echo "  1) Merge hooks/settings-hooks-snippet.json into ~/.claude/settings.json"
echo "  2) Launch: ${PET}/bin/ClawPet &"
echo "  3) Grant Accessibility permission when prompted (enables the typing state)"
