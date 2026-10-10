#!/bin/bash
# antigravity-statusline-shim.sh — the Antigravity CLI capture AND render
# channel (spec 0206 PLAN v3 step 13; spec 0249 delta-01 PLAN v5 step 5).
# Antigravity exposes no lifecycle hook event for usage capture — the
# display-command invocation the CLI already makes for a user-configured
# status line IS the only trigger this channel has. This shim composes THREE
# concerns on the one process the CLI invokes:
#   1. Render — when renderEnabled is true, pipes the payload to the
#      CrewRig-owned enhanced script at $AGY_HOME/statusline.py.
#   2. Capture — tees the payload to the capture step's Antigravity adapter
#      (scripts/lib/usage-capture/adapters/antigravity.js, via cli.js — the
#      same module tree hooks/usage-capture.sh reaches). Unconditional,
#      exactly as before this ticket — the marker's usageCaptureEnabled flag
#      governs the SETUP SCRIPT's install/opt-in UX, not this runtime call.
#   3. Legacy foreign-prior-command forward — when a priorStatusLineCommand
#      was configured (a value this shim replaced when it was first wired),
#      the shim streams the payload to it and composes its output with the
#      render output, rather than discarding it (spec 0241 R2).
#
# Four-state stdout contract: render-only -> RENDERED; prior-only ->
# PRIOR_OUTPUT; both non-empty -> "RENDERED | PRIOR_OUTPUT"; both empty ->
# emit NOTHING (not even a blank line) — the state 100% of installs were in
# before this ticket, and the state every install with neither flag enabled
# stays in today. The final print is GUARDED on a non-empty FINAL for
# exactly this reason: an earlier revision of this shim made the print
# unconditional, which would have emitted a bare newline for every
# currently-installed user instead of the documented zero bytes — caught in
# review (PLAN v4-F1) and corrected here. Do not drop this guard again.
#
# THIS FILE IS NEVER COPIED OUT of the repository, exactly like
# hooks/usage-capture.sh (spec 0206 PLAN v3 step 11): its whole job is to
# reach the sibling module tree, so scripts/setup-antigravity-interactive.sh
# wires statusLine.command to THIS file's own in-repo absolute path,
# installed only when both flags transition from fully-disabled to enabled.
#
# Exit code: ALWAYS 0, the same R15 contract hooks/usage-capture.sh carries —
# a render failure, a capture failure, or a prior-command failure must never
# break the status-line display (spec 0249 R9/R10).
#
# Environment: the same CREWRIG_USAGE_ROOT / CREWRIG_USAGE_CAPTURE_CLI /
# CREWRIG_USAGE_CAPTURE_TEST contract hooks/usage-capture.sh documents, plus
# AGY_HOME (overridable for tests; defaults to ~/.gemini/antigravity-cli) for
# the enhanced render script's installed location.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CLI_JS="$DIR/../scripts/lib/usage-capture/cli.js"
if [ -n "${CREWRIG_USAGE_CAPTURE_TEST:-}" ] && [ -n "${CREWRIG_USAGE_CAPTURE_CLI:-}" ]; then
  CLI_JS="$CREWRIG_USAGE_CAPTURE_CLI"
fi

payload="$(cat)"

CREWRIG_USAGE_ROOT="${CREWRIG_USAGE_ROOT:-${HOME}/.crewrig/usage}"
STATUSLINE_MARKER="$CREWRIG_USAGE_ROOT/state/antigravity-statusline.json"
AGY_HOME="${AGY_HOME:-${HOME}/.gemini/antigravity-cli}"

PRIOR_CMD=""
RENDER_ENABLED="false"
if [ -f "$STATUSLINE_MARKER" ]; then
  PRIOR_CMD="$(jq -r '.priorStatusLineCommand // empty' "$STATUSLINE_MARKER" 2>/dev/null || true)"
  RENDER_ENABLED="$(jq -r '.renderEnabled // false' "$STATUSLINE_MARKER" 2>/dev/null || echo false)"
fi

# 3. Legacy foreign-prior-command forward — capture-then-compose, not live
# passthrough. NO trailing `|| PRIOR_OUTPUT=""` here: this file has no
# `set -e`, so a non-zero exit from the prior command does not abort the
# script, and a trailing guard would clobber text the command already wrote
# to stdout before failing (the exact bug this shim's v1->v2 cycle already
# caught and fixed once — not reintroduced).
PRIOR_OUTPUT=""
if [ -n "$PRIOR_CMD" ]; then
  PRIOR_OUTPUT="$(printf '%s' "$payload" | sh -c "$PRIOR_CMD" 2>/dev/null)"
fi

# 1. Render — only when the marker's renderEnabled flag is true.
RENDERED=""
if [ "$RENDER_ENABLED" = "true" ]; then
  RENDERED="$("$AGY_HOME/statusline.py" <<<"$payload" 2>/dev/null)" || RENDERED=""
fi

# Compose.
if [ -n "$RENDERED" ] && [ -n "$PRIOR_OUTPUT" ]; then
  FINAL="$RENDERED | $PRIOR_OUTPUT"
elif [ -n "$RENDERED" ]; then
  FINAL="$RENDERED"
elif [ -n "$PRIOR_OUTPUT" ]; then
  FINAL="$PRIOR_OUTPUT"
else
  FINAL=""
fi

# 2. Capture — unconditional, untouched by this ticket's render/compose work.
tmp="$(mktemp)"
printf '%s' "$payload" > "$tmp"
CREWRIG_USAGE_ROOT="$CREWRIG_USAGE_ROOT" \
  node --disable-warning=ExperimentalWarning "$CLI_JS" --cli antigravity --event statusline --payload-file "$tmp" >/dev/null 2>&1
rm -f "$tmp"

# Guarded print — NOT unconditional. Both-empty emits zero bytes, matching
# the documented silent-when-unconfigured behavior byte-for-byte.
[ -n "$FINAL" ] && printf '%s\n' "$FINAL"

exit 0
