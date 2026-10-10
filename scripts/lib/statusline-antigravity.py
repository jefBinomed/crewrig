#!/usr/bin/env python3
# statusline-antigravity.py — CrewRig-owned, vendored and enhanced copy of
# the user's personal Antigravity CLI statusline script (spec 0249 delta-01,
# PLAN v5 step 1). Installed by scripts/setup-antigravity-interactive.sh as a
# COPY (never a symlink, never an in-repo-path reference — stdlib-only, no
# sibling-module need) to $AGY_HOME/statusline.py, and invoked by
# hooks/antigravity-statusline-shim.sh only when the render flag is enabled.
#
# Keeps unchanged from the user's original script: color(), get_git_branch(),
# the three-line layout. Adds: a context-usage bar (R-less, mirrors
# ccstatusline's context-bar segment), a VCS dirty-state suffix sourced from
# the native payload alone (R18 — no extra subprocess), a TTL-cached
# working-tree change count (R19), a labeled cost estimate (R17), and a
# quota reset countdown. Two layout adjustments from JF, given after PLAN v5
# was approved: the branch/changes segment moved from line 1 to line 3
# (next to cwd), and the "Thinking: <state>" segment (agent_state) dropped
# entirely.
#
# Blanket failure containment: json.load() is already guarded (exits 0 on a
# malformed/absent payload). Everything after it — building line1/line2/
# line3 and the three print() calls — is wrapped in ONE outer
# try/except Exception: pass, so any helper failure yields empty stdout and
# a normal exit, never a half-rendered line (spec 0249 R4/R10).

import sys
import json
import subprocess
import os
import time
import hashlib


def color(text, code):
    return f"\033[{code}m{text}\033[0m"


def get_git_branch(cwd):
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=0.5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return ""


def get_git_changes(cwd):
    try:
        # Run git diff to get numstat for added/deleted lines
        result = subprocess.run(
            ['git', 'diff', 'HEAD', '--numstat'],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=0.5
        )
        added = 0
        deleted = 0
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 2:
                    if parts[0].isdigit():
                        added += int(parts[0])
                    if parts[1].isdigit():
                        deleted += int(parts[1])
            if added > 0 or deleted > 0:
                return f"(+{added},-{deleted})"
    except Exception:
        pass
    return ""


# --- R19: TTL-cached working-tree change count ------------------------------
# File-based cache at ~/.crewrig/statusline/cache/<sha256(cwd)>.json, storing
# {"writtenAt": <epoch float>, "value": "(+N,-M)"}. TTL = 5 seconds, matching
# ccstatusline's own gitCacheTtlSeconds (~/.config/ccstatusline/settings.json).
# Any read failure is treated as a miss, never raises (R19, R4).

GIT_CHANGES_CACHE_TTL_SECONDS = 5


def _git_changes_cache_path(cwd):
    key = hashlib.sha256(cwd.encode("utf-8")).hexdigest()
    return os.path.join(os.path.expanduser("~/.crewrig/statusline/cache"), f"{key}.json")


def get_cached_git_changes(cwd):
    cache_path = _git_changes_cache_path(cwd)
    now = time.time()
    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            cached = json.load(f)
        written_at = cached.get("writtenAt")
        if written_at is not None and (now - written_at) < GIT_CHANGES_CACHE_TTL_SECONDS:
            return cached.get("value", "")
    except Exception:
        pass

    value = get_git_changes(cwd)
    try:
        cache_dir = os.path.dirname(cache_path)
        os.makedirs(cache_dir, exist_ok=True)
        tmp_path = f"{cache_path}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump({"writtenAt": now, "value": value}, f)
        os.replace(tmp_path, cache_path)
    except Exception:
        pass
    return value


# --- R17: labeled cost estimate ---------------------------------------------
# Pricing-source lookup order: (a) the pinned LiteLLM snapshot at
# <CREWRIG_USAGE_ROOT|~/.crewrig/usage>/pricelist/PINNED.json + <sha>.json,
# mirroring scripts/lib/usage-price/pricelist.js's pinned() read-only
# contract (never triggers refresh()); (b) on any failure, the embedded
# fallback table below; (c) if neither has an entry, None — the cost segment
# is omitted entirely, never a zero, a placeholder, or an unlabeled guess.

EMBEDDED_PRICING = {
    # Fallback rates (USD per token), used only when the pinned snapshot is
    # absent or has no entry for the active model id. Mirrors the rates this
    # script hardcoded before this enhancement (~$1.25/1M in, ~$5.00/1M out
    # for Gemini Pro-class models; a cheaper rate for Flash-class models).
    "gemini-3.1-pro-preview": {"input_cost_per_token": 0.00000125, "output_cost_per_token": 0.000005},
    "gemini-3.8-flash": {"input_cost_per_token": 0.0000002, "output_cost_per_token": 0.0000005},
    "gemini-3.5-flash": {"input_cost_per_token": 0.0000002, "output_cost_per_token": 0.0000005},
}


def _pricelist_root():
    # Mirrors scripts/lib/usage-store/layout.js's resolveRoot(): honours
    # CREWRIG_USAGE_ROOT, defaults to ~/.crewrig/usage.
    return os.environ.get("CREWRIG_USAGE_ROOT") or os.path.expanduser("~/.crewrig/usage")


def _load_pinned_pricelist_entries():
    # Mirrors layout.js's pricelistDir() (<root>/pricelist) and
    # pinnedPointer() (<root>/pricelist/PINNED.json), and pricelist.js's
    # pinned() reader: the pointer names a sha, the blob at
    # <root>/pricelist/<sha>.json holds the entry map. Read-only — never
    # writes, never triggers a refresh.
    root = _pricelist_root()
    pointer_path = os.path.join(root, "pricelist", "PINNED.json")
    with open(pointer_path, "r", encoding="utf-8") as f:
        pointer = json.load(f)
    sha = pointer["sha"]
    blob_path = os.path.join(root, "pricelist", f"{sha}.json")
    with open(blob_path, "r", encoding="utf-8") as f:
        return json.load(f)


def estimate_cost(model_id, in_tok, out_tok):
    if not model_id:
        return None

    entry = None
    try:
        entries = _load_pinned_pricelist_entries()
        entry = entries.get(model_id)
    except Exception:
        entry = None

    if not entry:
        entry = EMBEDDED_PRICING.get(model_id)

    if not entry:
        return None

    input_rate = entry.get("input_cost_per_token")
    output_rate = entry.get("output_cost_per_token")
    if input_rate is None and output_rate is None:
        return None

    return (in_tok * (input_rate or 0)) + (out_tok * (output_rate or 0))


# --- Context-usage bar (mirrors ccstatusline's context-bar slider) ---------

def render_bar(pct, width=10):
    pct = max(0.0, min(100.0, pct))
    filled = int(round((pct / 100.0) * width))
    filled = max(0, min(width, filled))
    bar = ("█" * filled) + ("░" * (width - filled))
    return color(bar, "33")  # yellow


def format_reset_countdown(seconds):
    try:
        seconds = int(seconds)
    except (TypeError, ValueError):
        return None
    if seconds < 0:
        return None
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    if hours > 0:
        return f"{hours}h{minutes:02d}m"
    return f"{minutes}m"


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    try:
        cyan = "36"
        blue = "34"
        bright_red = "91"
        green = "32"
        gray = "90"

        sep = color(" | ", gray)

        # --- Line 1: Model / context window ---
        model_name = data.get("model", {}).get("display_name", "Unknown")
        model_str = f"Model: {model_name}"

        cw = data.get("context_window", {}) or {}
        cw_size = cw.get("context_window_size", 0)
        win_str = f"Win: {cw_size // 1000}k" if cw_size > 0 else "Win: ?"

        cw_pct = cw.get("used_percentage", 0)
        bar_str = f"Ctx {render_bar(cw_pct)} {cw_pct:.1f}%"

        line1 = [color(model_str, cyan), color(win_str, cyan), bar_str]

        # --- Line 2: Session usage / tokens / cost ---
        quota = (data.get("quota") or {}).get("gemini-weekly", {}) or {}
        rem_frac = quota.get("remaining_fraction")
        session_val = ((1.0 - rem_frac) * 100) if rem_frac is not None else 0.0
        session_str = f"Session: {session_val:.1f}%"
        reset_countdown = format_reset_countdown(quota.get("reset_in_seconds"))
        if reset_countdown:
            session_str = f"{session_str} (reset {reset_countdown})"

        in_tok = cw.get("total_input_tokens", 0)
        out_tok = cw.get("total_output_tokens", 0)
        tot_tok = in_tok + out_tok
        tot_str = f"Total: {tot_tok / 1000:.1f}k"

        line2 = [f"  {color(session_str, blue)}", color(tot_str, bright_red)]

        model_id = data.get("model", {}).get("id")
        cost = estimate_cost(model_id, in_tok, out_tok)
        if cost is not None:
            # "~" prefix labels this as an estimate (R17) — never presented
            # identically to a native, non-estimated cost figure.
            line2.append(color(f"~${cost:.3f}", bright_red))

        # --- Line 3: cwd + VCS branch/dirty/changes (moved from line 1) ---
        cwd = data.get("cwd", os.getcwd())
        vcs = data.get("vcs", {}) or {}
        branch = vcs.get("branch", "")
        if not branch:
            branch = get_git_branch(cwd)

        line3 = [f"  cwd: {color(cwd, green)}"]
        if branch:
            dirty_suffix = "*" if vcs.get("dirty") else ""
            changes_str = get_cached_git_changes(cwd)
            git_combined = f"⎇ {branch}{dirty_suffix} {changes_str}".strip()
            line3.append(color(git_combined, "33"))  # yellow

        print(sep.join(line1))
        print(sep.join(line2))
        print(sep.join(line3))
    except Exception:
        pass


if __name__ == "__main__":
    main()
