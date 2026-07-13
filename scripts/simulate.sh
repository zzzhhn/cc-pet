#!/usr/bin/env bash
# Drive all 13 states so you can eyeball each animation. Requires ClawPet running.
set -e
OUT="${HOME}/.claude/pet/state.json"; mkdir -p "$(dirname "$OUT")"
for s in greet hover working typing waiting cheer droop singing fly-left fly-right wave twirl hearts; do
  printf '{"state":"%s"}' "$s" > "$OUT"; echo "-> $s"; sleep 2
done
echo "done (13 states)"
