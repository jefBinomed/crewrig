#!/bin/bash
# test-statusline-antigravity-script.sh — Regression tests for the
# CrewRig-owned, vendored Antigravity statusline renderer (spec 0249
# delta-01, PLAN v5 step 7, issue #4).
#
# Unit under test: scripts/lib/statusline-antigravity.py, driven directly via
# stdin — no setup script, no CLI install, no MCP session.
#
# Contract asserted:
#   R18 — vcs.dirty renders a `*` suffix on the branch segment, now on line 3
#     (moved there post-PLAN-v5-approval, next to cwd; the branch/changes
#     segment no longer appears on line 1).
#   R17 — a known model id renders a `~$`-prefixed cost estimate; an unknown
#     model id (absent from both the pinned pricelist and the embedded
#     fallback table) omits the cost segment ENTIRELY — no "0.000", no
#     placeholder.
#   R19 — the TTL-cached working-tree change count: a cold cache computes and
#     caches a value; a second invocation within the 5s TTL returns the SAME
#     cached value even when `git` is shadowed by a failing stub (proving the
#     cache, not a fresh subprocess, served it); a third invocation after the
#     cache entry is aged past the TTL, with `git` still shadowed, omits the
#     change-count field and still exits 0 (a cache miss must never raise).
#   R4/R10 — malformed/non-JSON stdin exits 0 with no output (regression guard
#     on the pre-existing, unmodified `except: sys.exit(0)` around json.load);
#     a forced internal exception AFTER the JSON parses (a payload field of a
#     type that breaks downstream formatting) still exits 0 with EMPTY
#     stdout, never a half-rendered line — proving the blanket
#     `try/except Exception: pass` wrapping main()'s post-parse body actually
#     works, not merely that each helper is individually defensive.
#
# HERMETIC: HOME is sandboxed to a temp directory for every invocation, so the
# TTL cache (~/.crewrig/statusline/cache/) and the pinned-pricelist lookup
# (~/.crewrig/usage/pricelist/) never touch the operator's real machine state.
# No network. A real `git` binary and a scratch git repository are used for
# the cache test (R19) — real-dependency per this repo's testing convention,
# since the behavior under test IS the subprocess-vs-cache boundary.
#
# Usage:
#   bash scripts/tests/test-statusline-antigravity-script.sh
#
# Override the interpreter with CREWRIG_TEST_PYTHON (default: python3).

# -e intentionally omitted: pass/fail counters drive the harness, and several
# probes intentionally assert a non-zero/empty result.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/lib/statusline-antigravity.py"
PYTHON_BIN="${CREWRIG_TEST_PYTHON:-python3}"

[ -f "$SCRIPT" ] || { echo "FATAL: missing $SCRIPT" >&2; exit 2; }
command -v "$PYTHON_BIN" >/dev/null 2>&1 || { echo "FATAL: interpreter '$PYTHON_BIN' not found" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FATAL: git is required for the R19 cache test" >&2; exit 2; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

# run_statusline <home> <payload-json>
# Invokes the script with HOME sandboxed to $1, feeds $2 on stdin, and
# captures stdout to a file (never via `$(...)`, which strips trailing
# newlines and cannot distinguish zero bytes from a bare newline — load-bearing
# for the R4/R10 empty-stdout assertion below).
run_statusline() {
  local home="$1" payload="$2" out_file="$3"
  : > "$out_file"
  HOME="$home" "$PYTHON_BIN" "$SCRIPT" <<<"$payload" > "$out_file" 2>/dev/null
  echo $?
}

# ---------------------------------------------------------------------------
echo "§1 vcs.dirty renders a '*' suffix on line 3 (R18)"
# ---------------------------------------------------------------------------

HOME_1="$TMP_ROOT/home-1"; mkdir -p "$HOME_1"
CWD_1="$TMP_ROOT/cwd-1"; mkdir -p "$CWD_1"
PAYLOAD_1=$(cat <<EOF
{"cwd":"$CWD_1","model":{"id":"m","display_name":"M"},
 "context_window":{"context_window_size":100000,"used_percentage":10.0,
   "total_input_tokens":0,"total_output_tokens":0},
 "vcs":{"branch":"feature-x","dirty":true}}
EOF
)
OUT_1="$TMP_ROOT/out-1"
STATUS_1="$(run_statusline "$HOME_1" "$PAYLOAD_1" "$OUT_1")"
LINE1_1="$(sed -n '1p' "$OUT_1")"
LINE3_1="$(sed -n '3p' "$OUT_1")"

if [ "$STATUS_1" -eq 0 ]; then ok "exits 0"; else bad "exit status was $STATUS_1"; fi
if [[ "$LINE3_1" == *"feature-x*"* ]]; then
  ok "R18: line 3 carries the dirty-state '*' suffix on the branch"
else
  bad "R18: line 3 missing dirty suffix (got: $LINE3_1)"
fi
if [[ "$LINE1_1" != *"feature-x"* ]]; then
  ok "R18: line 1 no longer carries the branch segment (moved to line 3)"
else
  bad "R18: line 1 unexpectedly still carries the branch segment (got: $LINE1_1)"
fi

# Clean (non-dirty) branch must NOT carry the suffix.
PAYLOAD_1B=$(cat <<EOF
{"cwd":"$CWD_1","model":{"id":"m"},
 "context_window":{"context_window_size":100000,"used_percentage":10.0,
   "total_input_tokens":0,"total_output_tokens":0},
 "vcs":{"branch":"feature-x","dirty":false}}
EOF
)
OUT_1B="$TMP_ROOT/out-1b"
run_statusline "$HOME_1" "$PAYLOAD_1B" "$OUT_1B" >/dev/null
LINE3_1B="$(sed -n '3p' "$OUT_1B")"
if [[ "$LINE3_1B" == *"feature-x"* ]] && [[ "$LINE3_1B" != *"feature-x*"* ]]; then
  ok "R18: a clean branch (dirty:false) carries no '*' suffix"
else
  bad "R18: clean-branch rendering is wrong (got: $LINE3_1B)"
fi

echo ""
# ---------------------------------------------------------------------------
echo "§2 labeled cost estimate vs. omitted cost (R17)"
# ---------------------------------------------------------------------------

HOME_2="$TMP_ROOT/home-2"; mkdir -p "$HOME_2"
CWD_2="$TMP_ROOT/cwd-2"; mkdir -p "$CWD_2"

# Known model id (present in the embedded fallback table) + a sandboxed HOME
# with no pinned pricelist -> falls through to EMBEDDED_PRICING.
PAYLOAD_2A=$(cat <<EOF
{"cwd":"$CWD_2","model":{"id":"gemini-3.1-pro-preview"},
 "context_window":{"context_window_size":100000,"used_percentage":5.0,
   "total_input_tokens":100000,"total_output_tokens":50000},
 "vcs":{"branch":"main"}}
EOF
)
OUT_2A="$TMP_ROOT/out-2a"
STATUS_2A="$(run_statusline "$HOME_2" "$PAYLOAD_2A" "$OUT_2A")"
if [ "$STATUS_2A" -eq 0 ] && grep -qE '~\$[0-9]+\.[0-9]{3}' "$OUT_2A"; then
  ok "R17: a known model id renders a '~\$'-prefixed cost estimate"
else
  bad "R17: known-model cost segment missing or malformed: $(cat "$OUT_2A")"
fi

# Unknown model id: absent from the embedded table AND no pinned pricelist
# exists under the sandboxed HOME -> the cost segment must be OMITTED, never
# a zero or a placeholder.
PAYLOAD_2B=$(cat <<EOF
{"cwd":"$CWD_2","model":{"id":"totally-unknown-model-xyz"},
 "context_window":{"context_window_size":100000,"used_percentage":5.0,
   "total_input_tokens":100000,"total_output_tokens":50000},
 "vcs":{"branch":"main"}}
EOF
)
OUT_2B="$TMP_ROOT/out-2b"
STATUS_2B="$(run_statusline "$HOME_2" "$PAYLOAD_2B" "$OUT_2B")"
if [ "$STATUS_2B" -eq 0 ] && ! grep -q '~\$' "$OUT_2B" && ! grep -q '0\.000' "$OUT_2B"; then
  ok "R17: an unknown model id omits the cost segment entirely (no placeholder)"
else
  bad "R17: unknown-model cost segment present or a placeholder leaked: $(cat "$OUT_2B")"
fi

echo ""
# ---------------------------------------------------------------------------
echo "§3 TTL-cached working-tree change count: hit / shadowed-miss-after-expiry (R19)"
# ---------------------------------------------------------------------------

HOME_3="$TMP_ROOT/home-3"; mkdir -p "$HOME_3"
REPO_3="$TMP_ROOT/repo-3"
mkdir -p "$REPO_3"
git -C "$REPO_3" init -q
git -C "$REPO_3" config user.email "test@example.com"
git -C "$REPO_3" config user.name "Test"
echo "one" > "$REPO_3/f.txt"
git -C "$REPO_3" add f.txt
git -C "$REPO_3" commit -q -m "initial"
echo "one
two" > "$REPO_3/f.txt"   # uncommitted change against HEAD -> non-empty numstat

PAYLOAD_3=$(cat <<EOF
{"cwd":"$REPO_3","model":{"id":"m"},
 "context_window":{"context_window_size":100000,"used_percentage":5.0,
   "total_input_tokens":0,"total_output_tokens":0},
 "vcs":{"branch":"main"}}
EOF
)

# Cold-cache invocation: real git available, computes and caches the value.
OUT_3A="$TMP_ROOT/out-3a"
STATUS_3A="$(run_statusline "$HOME_3" "$PAYLOAD_3" "$OUT_3A")"
LINE3_3A="$(sed -n '3p' "$OUT_3A")"
CACHE_DIR_3="$HOME_3/.crewrig/statusline/cache"
CACHE_FILE_3="$(find "$CACHE_DIR_3" -name '*.json' 2>/dev/null | head -n1)"

if [ "$STATUS_3A" -eq 0 ] && [[ "$LINE3_3A" == *"(+"*",-"*")"* ]]; then
  ok "R19: cold-cache invocation computes and renders a change count"
else
  bad "R19: cold-cache invocation did not render a change count (got: $LINE3_3A)"
fi
if [ -n "$CACHE_FILE_3" ] && [ -f "$CACHE_FILE_3" ]; then
  ok "R19: the change count was persisted to the TTL cache file"
else
  bad "R19: no cache file was written under $CACHE_DIR_3"
fi

# Shadow git with a failing stub, ahead of the real git on PATH.
FAKE_BIN_3="$TMP_ROOT/fakebin-3"
mkdir -p "$FAKE_BIN_3"
cat > "$FAKE_BIN_3/git" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$FAKE_BIN_3/git"

# Second invocation, within the 5s TTL, git shadowed: must still render the
# SAME cached value (proves the cache served it, not a fresh subprocess).
OUT_3B="$TMP_ROOT/out-3b"
PATH="$FAKE_BIN_3:$PATH" HOME="$HOME_3" "$PYTHON_BIN" "$SCRIPT" <<<"$PAYLOAD_3" > "$OUT_3B" 2>/dev/null
STATUS_3B=$?
LINE3_3B="$(sed -n '3p' "$OUT_3B")"
if [ "$STATUS_3B" -eq 0 ] && [ "$LINE3_3B" = "$LINE3_3A" ]; then
  ok "R19: within TTL, a shadowed/failing git still renders the cached value unchanged"
else
  bad "R19: within-TTL cache hit failed (expected '$LINE3_3A', got '$LINE3_3B', exit $STATUS_3B)"
fi

# Age the cache entry past the 5s TTL by rewriting writtenAt.
jq '.writtenAt = (now - 6)' "$CACHE_FILE_3" > "${CACHE_FILE_3}.tmp" && mv "${CACHE_FILE_3}.tmp" "$CACHE_FILE_3"

# Third invocation, cache expired, git still shadowed: must be a miss that
# OMITS the change-count field (git fails, no exception) and still exits 0.
OUT_3C="$TMP_ROOT/out-3c"
PATH="$FAKE_BIN_3:$PATH" HOME="$HOME_3" "$PYTHON_BIN" "$SCRIPT" <<<"$PAYLOAD_3" > "$OUT_3C" 2>/dev/null
STATUS_3C=$?
LINE3_3C="$(sed -n '3p' "$OUT_3C")"
if [ "$STATUS_3C" -eq 0 ] && [[ "$LINE3_3C" != *"(+"* ]]; then
  ok "R19: an expired cache entry with git shadowed omits the change-count field, exits 0"
else
  bad "R19: expired-cache-miss case failed (got: '$LINE3_3C', exit $STATUS_3C)"
fi

echo ""
# ---------------------------------------------------------------------------
echo "§4 malformed stdin and a forced internal exception (R4/R10)"
# ---------------------------------------------------------------------------

HOME_4="$TMP_ROOT/home-4"; mkdir -p "$HOME_4"

# (d) malformed/non-JSON stdin -> exits 0, no output (regression guard on the
# pre-existing json.load try/except).
OUT_4A="$TMP_ROOT/out-4a"
STATUS_4A="$(run_statusline "$HOME_4" 'this is not json { broken' "$OUT_4A")"
BYTES_4A="$(wc -c < "$OUT_4A" | tr -d ' ')"
if [ "$STATUS_4A" -eq 0 ] && [ "$BYTES_4A" -eq 0 ]; then
  ok "R4/R10: malformed/non-JSON stdin exits 0 with zero bytes of stdout"
else
  bad "R4/R10: malformed-stdin case failed (exit $STATUS_4A, $BYTES_4A bytes of stdout)"
fi

# (e) a forced internal exception AFTER json.load succeeds: used_percentage is
# a string, which raises a TypeError inside render_bar()'s min()/max() calls
# -- deep in the post-parse rendering body, not the already-guarded parse
# step. Proves the BLANKET try/except around main()'s body, not just that
# json.load is guarded.
PAYLOAD_4B='{"model":{"id":"m"},"context_window":{"used_percentage":"not-a-number"}}'
OUT_4B="$TMP_ROOT/out-4b"
STATUS_4B="$(run_statusline "$HOME_4" "$PAYLOAD_4B" "$OUT_4B")"
BYTES_4B="$(wc -c < "$OUT_4B" | tr -d ' ')"
if [ "$STATUS_4B" -eq 0 ] && [ "$BYTES_4B" -eq 0 ]; then
  ok "R4/R10: a forced internal exception after parsing still exits 0 with zero bytes of stdout"
else
  bad "R4/R10: forced-exception case failed (exit $STATUS_4B, $BYTES_4B bytes of stdout: $(cat "$OUT_4B"))"
fi

# ---------------------------------------------------------------------------
echo ""
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
