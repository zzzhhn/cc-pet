#!/usr/bin/env bash
# Feed representative hook JSON on stdin (as Claude Code does) and assert the written state.
set -e
REPO="$(git rev-parse --show-toplevel)"
BIN="${REPO}/desktop-pet/hooks/pet-state"
export HOME="$(mktemp -d)"
S="test-session-1"
st() { python3 -c "import json,sys;print(json.load(open('$HOME/.claude/pet/state.json'))['state'])"; }

# SessionStart -> greet (resets counter)
printf '{"hook_event_name":"SessionStart","session_id":"%s","source":"startup"}' "$S" | "$BIN" SessionStart
[ "$(st)" = "greet" ] || { echo "FAIL SessionStart"; exit 1; }

# UserPromptSubmit -> working (new turn, reset)
printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s"}' "$S" | "$BIN" UserPromptSubmit
[ "$(st)" = "working" ] || { echo "FAIL UserPromptSubmit"; exit 1; }

# Notification -> waiting
printf '{"hook_event_name":"Notification","session_id":"%s","message":"x"}' "$S" | "$BIN" Notification
[ "$(st)" = "waiting" ] || { echo "FAIL Notification"; exit 1; }

# Notification idle_prompt -> hover (Claude just idle, not waiting on you)
printf '{"hook_event_name":"Notification","session_id":"%s","notification_type":"idle_prompt"}' "$S" | "$BIN" Notification
[ "$(st)" = "hover" ] || { echo "FAIL idle->hover"; exit 1; }

# Notification permission_prompt -> waiting
printf '{"hook_event_name":"Notification","session_id":"%s","notification_type":"permission_prompt"}' "$S" | "$BIN" Notification
[ "$(st)" = "waiting" ] || { echo "FAIL permission->waiting"; exit 1; }

# PostToolUse with isError:true -> droop
printf '{"hook_event_name":"PostToolUse","session_id":"%s","tool_name":"Bash","isError":true}' "$S" | "$BIN" PostToolUse
[ "$(st)" = "droop" ] || { echo "FAIL droop"; exit 1; }

# PostToolUse ok -> working
printf '{"hook_event_name":"PostToolUse","session_id":"%s","tool_name":"Bash","isError":false}' "$S" | "$BIN" PostToolUse
[ "$(st)" = "working" ] || { echo "FAIL PostToolUse ok"; exit 1; }

# Stop with few tools -> cheer  (fresh turn)
printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s"}' "$S" | "$BIN" UserPromptSubmit
printf '{"hook_event_name":"Stop","session_id":"%s","stop_reason":"end_turn"}' "$S" | "$BIN" Stop
[ "$(st)" = "cheer" ] || { echo "FAIL Stop->cheer"; exit 1; }

# Stop after >=8 PreToolUse -> singing
printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s"}' "$S" | "$BIN" UserPromptSubmit
for i in $(seq 1 8); do
  printf '{"hook_event_name":"PreToolUse","session_id":"%s","tool_name":"Bash"}' "$S" | "$BIN" PreToolUse
done
printf '{"hook_event_name":"Stop","session_id":"%s","stop_reason":"end_turn"}' "$S" | "$BIN" Stop
[ "$(st)" = "singing" ] || { echo "FAIL Stop->singing"; exit 1; }

echo "pet-state stdin-JSON tests OK (greet/working/waiting/droop/cheer/singing)"
