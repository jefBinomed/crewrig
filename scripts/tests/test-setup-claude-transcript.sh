#!/bin/bash
# test-setup-claude-transcript.sh — Regression tests for Claude Code transcript
# and worktree git guard hook manifest wiring (spec 0169, issue #990).
#
# Unit under test:
#   - hooks/claude-transcript-hooks.json (the shipped manifest)
#   - the jq transform that scripts/setup-claude-interactive.sh applies to the
#     manifest at setup time.
#
# Contract asserted:
#   R1 — the shipped manifest is valid JSON containing PreToolUse (guard) and
#        lifecycle event hooks (transcripts).
#   R2 — the setup transform rewrites mempalace-transcript.sh to the installed
#        target path and worktree-git-guard.sh to the in-repo absolute path.
#   R3 — zero $CLAUDE_PROJECT_DIR placeholder tokens survive in the patched output.
#   spec 0211 R2 — the session-recording manifest registers no usage-capture.sh
#        command: usage capture has its own opt-in, covered (with the
#        never-copied invariant for usage-capture.sh) by
#        scripts/tests/test-setup-usage-capture-optin.sh.
#
# HERMETIC: no HOME writes, no network, no interactive script runs. All
# transforms target throwaway paths under a temp root removed on exit.
#
# Usage:
#   bash scripts/tests/test-setup-claude-transcript.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="$REPO_DIR/hooks/claude-transcript-hooks.json"
SETUP="$REPO_DIR/scripts/setup-claude-interactive.sh"

COMMON_LIB="$REPO_DIR/scripts/lib/common.sh"

for f in "$MANIFEST" "$SETUP" "$COMMON_LIB"; do
  [ -f "$f" ] || { echo "FATAL: missing $f" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required for this test" >&2; exit 2; }

# §3 (ccstatusline install block) sources a real snippet of $SETUP, which
# calls backup_file() — needed here, not re-implemented.
# shellcheck disable=SC2034  # read by install_file()/backup_file() if invoked
INSTALL_MODE="copy"
# shellcheck source=scripts/lib/common.sh
source "$COMMON_LIB"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

# ---------------------------------------------------------------------------
# §1. The shipped manifest is valid JSON with expected structure (R1).
# ---------------------------------------------------------------------------
echo "§1 manifest schema (R1)"

if jq -e . "$MANIFEST" >/dev/null 2>&1; then
  ok "manifest is valid JSON"
else
  bad "manifest is not valid JSON"
fi

if [ "$(jq -r '.hooks | type' "$MANIFEST" 2>/dev/null)" = "object" ]; then
  ok "hooks is an object"
else
  bad "hooks is not an object"
fi

guard_raw="$(jq -r '.hooks.PreToolUse[0].hooks[0].command // ""' "$MANIFEST" 2>/dev/null)"
if [[ "$guard_raw" == *"\$CLAUDE_PROJECT_DIR/hooks/worktree-git-guard.sh"* ]]; then
  ok "PreToolUse declares worktree-git-guard.sh with project token"
else
  bad "PreToolUse missing expected guard command (got: $guard_raw)"
fi

# ---------------------------------------------------------------------------
# §2. Replay the setup patch transform (R2, R3).
# ---------------------------------------------------------------------------
echo "§2 setup patch transform (R2, R3)"
HOOK_TARGET="$TMP_ROOT/claude/hooks/mempalace-transcript.sh"
GUARD_TARGET="$REPO_DIR/hooks/worktree-git-guard.sh"
PATCHED="$TMP_ROOT/patched.json"

jq --arg hook_path "$HOOK_TARGET" --arg guard_path "$GUARD_TARGET" \
  '(.. | objects | select(.type? == "command") | .command) |=
     (gsub("\\$CLAUDE_PROJECT_DIR/hooks/mempalace-transcript.sh"; $hook_path) |
      gsub("\\$CLAUDE_PROJECT_DIR/hooks/worktree-git-guard.sh"; $guard_path))' \
  "$MANIFEST" > "$PATCHED" 2>/dev/null

if jq -e . "$PATCHED" >/dev/null 2>&1; then
  ok "patched output is valid JSON"
else
  bad "patched output is not valid JSON"
fi

# PreToolUse must point to the guard script in-repo
guard_patched="$(jq -r '.hooks.PreToolUse[0].hooks[0].command // ""' "$PATCHED" 2>/dev/null)"
if [[ "$guard_patched" == *"\"$GUARD_TARGET\""* ]]; then
  ok "PreToolUse rewritten to in-repo guard target"
else
  bad "PreToolUse not rewritten to in-repo guard target (got: $guard_patched)"
fi

# Lifecycle events must point to installed transcript hook
for ev in UserPromptSubmit PostToolUse Stop SessionEnd; do
  ev_cmd="$(jq -r --arg ev "$ev" '.hooks[$ev][0].hooks[0].command // ""' "$PATCHED" 2>/dev/null)"
  if [[ "$ev_cmd" == *"\"$HOOK_TARGET\""* ]]; then
    ok "event '$ev' rewritten to installed transcript hook"
  else
    bad "event '$ev' not correctly rewritten (got: $ev_cmd)"
  fi
done

# Zero project-directory tokens must survive (R3)
if grep -q '\$CLAUDE_PROJECT_DIR' "$PATCHED"; then
  bad "surviving \$CLAUDE_PROJECT_DIR token found in patched output"
else
  ok "zero \$CLAUDE_PROJECT_DIR placeholder tokens survive in patched output"
fi

# spec 0211 R2 — session recording no longer registers usage capture.
if jq -e '[.. | objects | select(.type? == "command") | .command | select(contains("usage-capture.sh"))] | length == 0' \
     "$PATCHED" >/dev/null 2>&1; then
  ok "no patched command names usage-capture.sh (spec 0211 R2)"
else
  bad "a patched session-recording command names usage-capture.sh (spec 0211 R2)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "§3 ccstatusline install block (spec 0249 delta-01, PLAN v5 steps 6, 9)"

# §3 exercises scripts/setup-claude-interactive.sh's "Status line: ccstatusline
# (opt-in)" block the same way the Antigravity suite's unified-install section
# exercises its own setup-script block: extracted verbatim with awk (bounded
# by its own header comment and the Team-selection section that follows),
# sourced in a subshell with `fzf` stubbed by a positional-answer function and
# HOME/PATH sandboxed, never run end-to-end (fzf prompts, real npm/network).
CCBLOCK="$TMP_ROOT/ccstatusline-block.sh"
awk 'index($0,"# --- Status line: ccstatusline (opt-in) ---"){p=1}
     p && index($0,"if [ \"$SKIP_RULES_CONFIG\" -ne 1 ]; then"){p=0}
     p{print}' "$SETUP" > "$CCBLOCK"
if [ -s "$CCBLOCK" ]; then
  ok "§3: the ccstatusline install block was located in the setup script"
else
  bad "§3: could not locate the ccstatusline install block — the marker comment moved?"
fi
# Tripwire: a runaway extraction would capture the team/expertise/level/
# profile selection blocks that follow, which read/write the operator's real
# catalogue picks — exactly what this suite's HERMETIC header promises not to do.
if grep -q 'pick_catalogue_entry' "$CCBLOCK"; then
  bad "§3: the extraction ran away past the ccstatusline block — end marker moved?"
else
  ok "§3: the extraction is bounded to the ccstatusline block"
fi

# Grep guard: the block must never open or write ccstatusline's own per-user
# config file — R16's "SHALL NOT overwrite the user's own segment
# configuration" is satisfied by never touching that file in any code path,
# including in a comment that could later be miscopied into real code.
if grep -q '\.config/ccstatusline' "$CCBLOCK"; then
  bad "§3: the block's source references ~/.config/ccstatusline — R16 violation risk"
else
  ok "§3: the block's source never references ~/.config/ccstatusline (R16)"
fi

# run_cc_block <claude_home> <path_prefix> <fzf answer> [fzf answer...]
# Sources CCBLOCK in a subshell (stubs never leak) with `fzf` answering
# positionally and PATH prefixed so `command -v ccstatusline`/`npm` resolve
# (or deliberately fail to) against test doubles instead of the real machine.
run_cc_block() {
  local claude_home="$1" path_prefix="$2"
  shift 2
  local -a answers=("$@")
  (
    _IDX_FILE="$TMP_ROOT/cc-fzf-idx.$$.$RANDOM"
    echo 0 > "$_IDX_FILE"
    fzf() {
      cat >/dev/null
      local i
      i="$(cat "$_IDX_FILE")"
      echo $((i + 1)) > "$_IDX_FILE"
      printf '%s\n' "${answers[$i]}"
    }
    CLAUDE_HOME="$claude_home"
    SETTINGS_TARGET="$claude_home/settings.json"
    HOME="$claude_home"
    REPO_DIR="$REPO_DIR"
    # A bare PATH PREFIX would not isolate anything: on a machine with a real,
    # globally-installed ccstatusline/npm (e.g. via nvm, or Homebrew's own
    # npm under /opt/homebrew/bin — confirmed live to exist alongside jq on
    # the authoring machine), `command -v` would still find them further down
    # an inherited or wholesale-included PATH. PATH here carries ONLY /usr/bin
    # and /bin (standard system utilities, no node/npm on this machine) plus
    # SAFE_BIN (jq only) and the test double directory.
    PATH="$path_prefix:/usr/bin:/bin:$SAFE_BIN"
    # shellcheck source=/dev/null
    . "$CCBLOCK"
  )
}

EMPTY_BIN="$TMP_ROOT/cc-emptybin"; mkdir -p "$EMPTY_BIN"

# SAFE_BIN carries ONLY a symlink to the real jq this block needs. Earlier
# drafts of this suite used /opt/homebrew/bin wholesale for jq and triggered a
# REAL `npm install -g ccstatusline` against Homebrew's npm during the
# absent-npm test, because Homebrew also ships npm on that same PATH entry —
# a machine-state side effect this HERMETIC suite must never cause. SAFE_BIN
# is the fix: it is used INSTEAD of any real binary directory that might also
# carry npm/node/ccstatusline.
SAFE_BIN="$TMP_ROOT/cc-safebin"; mkdir -p "$SAFE_BIN"
REAL_JQ="$(command -v jq)"
ln -s "$REAL_JQ" "$SAFE_BIN/jq"

# --- §3.1 shape-recognition no-op: statusLine already names ccstatusline ----
CC_HOME_1="$TMP_ROOT/cc-home-1"; mkdir -p "$CC_HOME_1"
CC_SETTINGS_1="$CC_HOME_1/settings.json"
printf '{"statusLine":{"type":"command","command":"ccstatusline","padding":0,"refreshInterval":10}}' > "$CC_SETTINGS_1"
SETTINGS_BEFORE_CC1="$(cat "$CC_SETTINGS_1")"
BIN_CC_1="$TMP_ROOT/cc-bin-1"; mkdir -p "$BIN_CC_1"
printf '#!/bin/sh\nexit 0\n' > "$BIN_CC_1/ccstatusline"; chmod +x "$BIN_CC_1/ccstatusline"

run_cc_block "$CC_HOME_1" "$BIN_CC_1" "yes" >/dev/null 2>&1

SETTINGS_AFTER_CC1="$(cat "$CC_SETTINGS_1")"
MARKER_CC1="$CC_HOME_1/.crewrig/statusline/state/claude-statusline.json"
if [ "$SETTINGS_AFTER_CC1" = "$SETTINGS_BEFORE_CC1" ]; then
  ok "§3.1: shape-recognition no-op leaves an already-ccstatusline statusLine untouched"
else
  bad "§3.1: settings.json was rewritten even though it already named ccstatusline (before: $SETTINGS_BEFORE_CC1, after: $SETTINGS_AFTER_CC1)"
fi
if [ -f "$MARKER_CC1" ]; then
  ok "§3.1: a marker is recorded for the recognized pre-existing install"
else
  bad "§3.1: no marker was recorded for the shape-recognized install"
fi
if ! ls "${CC_SETTINGS_1}".bak.* >/dev/null 2>&1; then
  ok "§3.1: no backup is made on the no-op path (nothing was changed)"
else
  bad "§3.1: a backup was unexpectedly created on the no-op path"
fi

echo ""

# --- §3.2 absent-binary / absent-npm skip paths -----------------------------
# Case A: neither ccstatusline nor npm resolve -> warns, installs nothing.
CC_HOME_2A="$TMP_ROOT/cc-home-2a"; mkdir -p "$CC_HOME_2A"
CC_SETTINGS_2A="$CC_HOME_2A/settings.json"
printf '{}' > "$CC_SETTINGS_2A"
OUT_2A="$(run_cc_block "$CC_HOME_2A" "$EMPTY_BIN" "yes" 2>&1)"
if [ "$(jq -r '.statusLine // empty' "$CC_SETTINGS_2A" 2>/dev/null)" = "" ] && [[ "$OUT_2A" == *"npm not found"* ]]; then
  ok "§3.2a: absent ccstatusline + absent npm warns and leaves statusLine untouched"
else
  bad "§3.2a: expected an npm-not-found warning and no statusLine key (settings: $(cat "$CC_SETTINGS_2A"), out: $OUT_2A)"
fi

# Case B: ccstatusline absent, npm present but the install attempt fails (the
# binary is still absent afterwards) -> warns, installs nothing.
CC_HOME_2B="$TMP_ROOT/cc-home-2b"; mkdir -p "$CC_HOME_2B"
CC_SETTINGS_2B="$CC_HOME_2B/settings.json"
printf '{}' > "$CC_SETTINGS_2B"
BIN_NPM_FAIL="$TMP_ROOT/cc-bin-npmfail"; mkdir -p "$BIN_NPM_FAIL"
printf '#!/bin/sh\nexit 1\n' > "$BIN_NPM_FAIL/npm"; chmod +x "$BIN_NPM_FAIL/npm"
OUT_2B="$(run_cc_block "$CC_HOME_2B" "$BIN_NPM_FAIL" "yes" 2>&1)"
if [ "$(jq -r '.statusLine // empty' "$CC_SETTINGS_2B" 2>/dev/null)" = "" ] && [[ "$OUT_2B" == *"install failed"* ]]; then
  ok "§3.2b: a failed npm install leaves ccstatusline absent and statusLine untouched"
else
  bad "§3.2b: expected an install-failed warning and no statusLine key (settings: $(cat "$CC_SETTINGS_2B"), out: $OUT_2B)"
fi

echo ""

# --- §3.3 R7 preview-and-choose when a foreign statusLine is present -------
CC_HOME_3="$TMP_ROOT/cc-home-3"; mkdir -p "$CC_HOME_3"
CC_SETTINGS_3="$CC_HOME_3/settings.json"
FOREIGN_CMD_CC3="/usr/bin/some-other-statusline-tool"
printf '{"statusLine":{"command":"%s"}}' "$FOREIGN_CMD_CC3" > "$CC_SETTINGS_3"
BIN_CC_3="$TMP_ROOT/cc-bin-3"; mkdir -p "$BIN_CC_3"
printf '#!/bin/sh\nexit 0\n' > "$BIN_CC_3/ccstatusline"; chmod +x "$BIN_CC_3/ccstatusline"

run_cc_block "$CC_HOME_3" "$BIN_CC_3" "yes" "replace-with-ccstatusline" >/dev/null 2>&1

MARKER_CC3="$CC_HOME_3/.crewrig/statusline/state/claude-statusline.json"
COMMAND_AFTER_CC3="$(jq -r '.statusLine.command // empty' "$CC_SETTINGS_3" 2>/dev/null)"
PRIOR_AFTER_CC3="$(jq -r '.priorStatusLineCommand // empty' "$MARKER_CC3" 2>/dev/null)"
if [ "$COMMAND_AFTER_CC3" = "ccstatusline" ]; then
  ok "§3.3: R7 'replace' wires statusLine.command to ccstatusline"
else
  bad "§3.3: statusLine.command after replace is '$COMMAND_AFTER_CC3', want 'ccstatusline'"
fi
if [ "$PRIOR_AFTER_CC3" = "$FOREIGN_CMD_CC3" ]; then
  ok "§3.3: the replaced foreign command is recorded as priorStatusLineCommand"
else
  bad "§3.3: priorStatusLineCommand is '$PRIOR_AFTER_CC3', want '$FOREIGN_CMD_CC3'"
fi
if ls "${CC_SETTINGS_3}".bak.* >/dev/null 2>&1; then
  ok "§3.3: settings.json is backed up before the replace transform"
else
  bad "§3.3: no settings.json.bak.* found after the replace transform"
fi

echo ""

# --- §3.4 keep/remove via the marker ----------------------------------------
# Keep: a marker-backed install is left untouched.
CC_HOME_4A="$TMP_ROOT/cc-home-4a"; mkdir -p "$CC_HOME_4A"
CC_SETTINGS_4A="$CC_HOME_4A/settings.json"
printf '{"statusLine":{"type":"command","command":"ccstatusline","padding":0,"refreshInterval":10}}' > "$CC_SETTINGS_4A"
mkdir -p "$CC_HOME_4A/.crewrig/statusline/state"
MARKER_CC4A="$CC_HOME_4A/.crewrig/statusline/state/claude-statusline.json"
printf '{"priorStatusLineCommand":"/usr/bin/previous-tool","installedBy":"test"}' > "$MARKER_CC4A"
SETTINGS_BEFORE_CC4A="$(cat "$CC_SETTINGS_4A")"

run_cc_block "$CC_HOME_4A" "$EMPTY_BIN" "keep" >/dev/null 2>&1

if [ "$(cat "$CC_SETTINGS_4A")" = "$SETTINGS_BEFORE_CC4A" ] && [ -f "$MARKER_CC4A" ]; then
  ok "§3.4: 'keep' leaves statusLine.command and the marker untouched"
else
  bad "§3.4: 'keep' altered settings.json or removed the marker"
fi

# Remove: restores the prior value and deletes the marker.
CC_HOME_4B="$TMP_ROOT/cc-home-4b"; mkdir -p "$CC_HOME_4B"
CC_SETTINGS_4B="$CC_HOME_4B/settings.json"
printf '{"statusLine":{"type":"command","command":"ccstatusline","padding":0,"refreshInterval":10}}' > "$CC_SETTINGS_4B"
mkdir -p "$CC_HOME_4B/.crewrig/statusline/state"
MARKER_CC4B="$CC_HOME_4B/.crewrig/statusline/state/claude-statusline.json"
PRIOR_CC4B="/usr/bin/previous-tool"
printf '{"priorStatusLineCommand":"%s","installedBy":"test"}' "$PRIOR_CC4B" > "$MARKER_CC4B"

run_cc_block "$CC_HOME_4B" "$EMPTY_BIN" "remove" >/dev/null 2>&1

COMMAND_AFTER_CC4B="$(jq -r '.statusLine.command // empty' "$CC_SETTINGS_4B" 2>/dev/null)"
if [ "$COMMAND_AFTER_CC4B" = "$PRIOR_CC4B" ]; then
  ok "§3.4: 'remove' restores statusLine.command to its prior value"
else
  bad "§3.4: statusLine.command after remove is '$COMMAND_AFTER_CC4B', want '$PRIOR_CC4B'"
fi
if [ ! -f "$MARKER_CC4B" ]; then
  ok "§3.4: 'remove' deletes the marker"
else
  bad "§3.4: the marker still exists after 'remove'"
fi
if ls "${CC_SETTINGS_4B}".bak.* >/dev/null 2>&1; then
  ok "§3.4: settings.json is backed up before the remove transform"
else
  bad "§3.4: no settings.json.bak.* found after the remove transform"
fi

# Remove with an empty prior value -> the statusLine key is deleted entirely.
CC_HOME_4C="$TMP_ROOT/cc-home-4c"; mkdir -p "$CC_HOME_4C"
CC_SETTINGS_4C="$CC_HOME_4C/settings.json"
printf '{"statusLine":{"type":"command","command":"ccstatusline","padding":0,"refreshInterval":10}}' > "$CC_SETTINGS_4C"
mkdir -p "$CC_HOME_4C/.crewrig/statusline/state"
MARKER_CC4C="$CC_HOME_4C/.crewrig/statusline/state/claude-statusline.json"
printf '{"priorStatusLineCommand":"","installedBy":"test"}' > "$MARKER_CC4C"

run_cc_block "$CC_HOME_4C" "$EMPTY_BIN" "remove" >/dev/null 2>&1

if [ "$(jq -r 'has("statusLine")' "$CC_SETTINGS_4C" 2>/dev/null)" = "false" ]; then
  ok "§3.4: 'remove' with an empty prior value deletes the statusLine key entirely"
else
  bad "§3.4: statusLine key still present after remove with an empty prior value"
fi

# ---------------------------------------------------------------------------
echo ""
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
