# Status-line rendering architecture

<!-- crewrig-doc: section=reference nav_order=116 published=true title="Status-line rendering architecture" -->

Spec 0249 (as pivoted by its delta-01) makes Claude Code's and Antigravity CLI's status lines comparable in the information each shows — active model, working directory, VCS state where available, and cost (native or estimated) — by relying on each CLI's own appropriate native-ecosystem tool to render it, rather than a CrewRig-authored shared renderer. This page documents the two install contracts, the unified Antigravity marker schema, the statusline shim's composition logic, and the cost-estimate and change-count caching mechanisms. Gemini CLI and GitHub Copilot CLI are out of scope (see *Parity gaps* below).

This page supersedes no prior document: the original shared-renderer architecture (spec 0249's initial PLAN v1/v2) was invalidated before DEV started against it, so no code or documentation for it ever existed. See `docs/usage-capture.md` → *Statusline shim wiring (Antigravity CLI)* for the usage-capture half of the Antigravity shim this page's render concern now shares a process with.

## Claude Code: the ccstatusline wrapper contract

Claude Code already has a rich, actively-maintained, separately-versioned third-party statusline tool: [`ccstatusline`](https://github.com/sirmalloc/ccstatusline). CrewRig does not fork, vendor, or patch it — `scripts/setup-claude-interactive.sh` only:

1. Ensures the `ccstatusline` binary is on `PATH`, installing it (`npm install -g ccstatusline`, through `scripts/lib/tls-exec.sh` for TLS-delegation consistency with every other setup-time `npm`/`npx` call) when it is absent. A missing `npm` is a non-fatal warning; the statusline question is simply not wired.
2. Merges `.statusLine = ((.statusLine // {}) + {type:"command", command:"ccstatusline", padding:0, refreshInterval:10})` into `~/.claude/settings.json`, leaving every other key untouched.
3. Records an install marker at `~/.crewrig/statusline/state/claude-statusline.json` (`{priorStatusLineCommand, installedBy}`), driving the `keep`/`remove` reinstall contract (spec 0249 R11) on a re-run.

**Shape recognition, not just the marker.** Before wiring, the installer checks whether `.statusLine.command` already looks like a `ccstatusline` invocation (the string `ccstatusline` appears in it), regardless of whether CrewRig's own marker exists. A match is treated as a no-op — CrewRig neither re-writes an already-correct value (spec 0249 R16: "wire the `statusLine` key to invoke it only when that key is not already pointed at it") nor resets whatever segment configuration the user already has. A marker is still recorded in this case so a future re-run offers `keep`/`remove` instead of asking "enable?" again.

**Never touches ccstatusline's own configuration.** `ccstatusline` keeps its own per-user segment layout in a file under its own config directory. CrewRig never opens, reads, or writes that file — only the `statusLine` key of Claude Code's `settings.json`, which merely names the command to invoke.

**R7 preview-and-choose.** When `statusLine.command` already carries a value this framework did not install and is not shaped like `ccstatusline`, the installer shows the existing value and lets the user choose `keep-existing` or `replace-with-ccstatusline` before touching anything.

## Antigravity CLI: the copy-install contract

Antigravity CLI's `statusLine.command` already serves one purpose before this delta: forwarding its native payload to the usage-capture adapter (spec 0206). This delta adds a second purpose — rendering an enhanced status line — to the *same* wired command, rather than opening a second slot (which would race for `statusLine.command`).

`scripts/setup-antigravity-interactive.sh` installs a CrewRig-owned, vendored, enhanced copy of the user's own personal Antigravity statusline script to `$AGY_HOME/statusline.py` (`~/.gemini/antigravity-cli/statusline.py`) from the in-repo source `scripts/lib/statusline-antigravity.py`. This is a **copy**, never a symlink and never an in-repo-path reference: the script is stdlib-only Python with no sibling-module dependency, so vendoring a copy avoids tying a user's live statusline to this checkout's lifetime (unlike the shim itself, which is deliberately wired by in-repo absolute path — see *Checkout-location dependency* in `docs/usage-capture.md`). The copy is fully CrewRig-owned: the user is not expected to hand-edit it outside CrewRig's own install/upgrade path (spec 0249 delta-01, resolved open question).

### The unified two-flag marker schema

One marker file, `~/.crewrig/usage/state/antigravity-statusline.json`, now carries two independent boolean flags:

```json
{
  "priorStatusLineCommand": "",
  "installedStatusLineCommand": "/abs/path/to/hooks/antigravity-statusline-shim.sh",
  "installedBy": "crewrig-setup-antigravity-interactive",
  "usageCaptureEnabled": true,
  "renderEnabled": true
}
```

- **`usageCaptureEnabled`** — gates the usage-capture opt-in UX in the setup script (the Node capture-forwarding call inside the shim itself runs unconditionally once wired, exactly as it did before this delta; this flag governs install/reinstall prompting, not a runtime branch).
- **`renderEnabled`** — gates whether the shim pipes the native payload through `$AGY_HOME/statusline.py`.

The two questions are asked independently, each with its own `keep`/`remove` on a re-run when already enabled. `statusLine.command` is wired exactly once, the first time either flag transitions from fully-disabled to enabled, and removed exactly once, when both flags transition back to fully-disabled (restoring `priorStatusLineCommand`, and restoring or deleting the installed script from its most recent backup).

**Legacy marker migration.** A marker written before this delta carries neither key. On first encounter, it is migrated **in place**, not defaulted: `usageCaptureEnabled: true` (it was already active — that is what the marker's prior existence means), `renderEnabled: false` (new, opt-in). The rewrite uses the same atomic `jq ... > "${MARKER}.tmp" && mv "${MARKER}.tmp" "$MARKER"` pattern every other write in this function already uses. If the rewrite fails, the in-memory migrated values are still used for that run; the next run retries the persisted write.

## The shim's three-concern composition

`hooks/antigravity-statusline-shim.sh` is the one process Antigravity CLI invokes for `statusLine.command`. It now composes three concerns on every invocation:

1. **Render** — when `renderEnabled` is `true`, pipes the payload to `$AGY_HOME/statusline.py` and captures its stdout.
2. **Capture** — tees the payload to the usage-capture adapter via `cli.js`, exactly as before this delta (unconditional, not gated on either flag — this is the pre-existing spec 0206 behavior, untouched).
3. **Legacy foreign-prior-command forward** — when a `priorStatusLineCommand` was recorded (a value the shim's wiring replaced), streams the payload to it and captures its output too, rather than discarding it (spec 0241 R2's composition requirement).

### The four-state stdout contract

| Render output | Prior-command output | Final stdout |
|---|---|---|
| non-empty | non-empty | `"<rendered> \| <prior>"` |
| non-empty | empty | `"<rendered>"` |
| empty | non-empty | `"<prior>"` |
| empty | empty | **nothing — not even a blank line** |

The both-empty row is the state 100% of today's installed base is in (no install has ever had a non-empty `priorStatusLineCommand`, since the shim is only ever wired when that value was previously empty). The final `printf` is **guarded** — `[ -n "$FINAL" ] && printf '%s\n' "$FINAL"` — specifically to preserve this row byte-for-byte. An earlier revision of this shim, during PLAN review, made the print unconditional; that would have emitted a bare newline for every currently-installed user instead of the documented zero bytes. Do not drop this guard.

The prior-command capture itself has no trailing `|| PRIOR_OUTPUT=""`: this file carries no `set -e`, so a non-zero exit from the prior command does not abort the script, and a trailing fallback would have clobbered text the command already wrote to stdout before failing non-zero — the exact regression an earlier revision cycle of this shim already caught and fixed once.

## Caching and failure containment in `statusline-antigravity.py`

**Blanket failure containment.** `json.load(sys.stdin)` is independently guarded (a malformed or absent payload exits 0 immediately, printing nothing). Everything after it — building all three rendered lines and the three `print()` calls — is wrapped in one outer `try/except Exception: pass`, so any single helper's failure (a missing field, an unexpected type) degrades to empty stdout and a normal exit, never a half-rendered line or a non-zero exit.

**Working-tree change count (R19).** `get_git_changes(cwd)` shells out to `git diff HEAD --numstat` — the one subprocess this feature permits beyond what the native payload supplies (spec 0249 delta-01 R19 carves out this exception from R2's no-extra-subprocess rule). To bound its cost on a channel that can fire up to ten times per turn, the result is cached at `~/.crewrig/statusline/cache/<sha256(cwd)>.json` as `{"writtenAt": <epoch float>, "value": "(+N,-M)"}`, with a 5-second TTL matching `ccstatusline`'s own `gitCacheTtlSeconds` (`~/.config/ccstatusline/settings.json`). Any cache-read failure (missing file, malformed JSON, missing `writtenAt`) is treated as a cache miss, never raised; any cache-write failure is silently ignored — the change count still renders from a fresh subprocess call, just without being cached for the next invocation.

**VCS branch and dirty state (R18).** `vcs.branch` and `vcs.dirty` are read directly from the native payload with no subprocess at all; `get_git_branch()` (a `git rev-parse` subprocess) is only a fallback for the rare case the payload's own `vcs.branch` is empty — unchanged from the user's original script.

**Cost estimate (R17).** `estimate_cost(model_id, in_tok, out_tok)` looks up `model.id` (verbatim — the same R30 "no display-name translation" convention `scripts/lib/usage-capture/adapters/antigravity.js` already documents) against two ordered sources:

1. The pinned LiteLLM snapshot — read-only, mirroring `scripts/lib/usage-price/pricelist.js`'s `pinned()` contract: `<CREWRIG_USAGE_ROOT|~/.crewrig/usage>/pricelist/PINNED.json` names a `sha`; the entry map lives at `<root>/pricelist/<sha>.json` (path algebra mirrors `scripts/lib/usage-store/layout.js`'s `pricelistDir()`/`pinnedPointer()`). Never triggers a refresh.
2. On any failure (file absent, corrupt JSON, no entry for the model id) — an embedded fallback table, `EMBEDDED_PRICING`, covering the Gemini model family the script already hardcoded a rate for before this enhancement.

If neither source has an entry, the cost segment is **omitted entirely** — never a zero, a placeholder, or an unlabeled guess (spec 0249 delta-01 R17's explicit failure scenario). When a cost is found, it renders as `~$<amount>` — the `~` prefix is the required visual distinction between this estimate and a CLI-native, non-estimated cost figure (R17); it is also what visually distinguishes this figure from `ccstatusline`'s own unlabeled, native `session-cost` segment on the Claude Code side.

## Layout notes

The exact visual layout is a PLAN-level and DEV-level styling choice, not spec-mandated (per the parent spec's and delta's own deferral). As implemented:

- **Line 1** — model, context window size, and a context-usage bar (mirrors `ccstatusline`'s `context-bar` slider segment).
- **Line 2** — session-usage percentage (with a reset countdown when the native payload's `quota.gemini-weekly.reset_in_seconds` is present), total tokens, and the labeled cost estimate when available.
- **Line 3** — working directory, plus the VCS branch (with a `*` dirty-state suffix and the cached `(+N,-M)` change count) when available.

The `agent_state` ("Thinking: …") segment from the user's original script is intentionally dropped; it carried no information the user found actionable in this context.

## Parity gaps

- **Gemini CLI** — no `statusLine`-equivalent hook exists in its settings schema or extension manifest. Documented gap, not a target for a workaround (parent spec 0249 → *Out of scope*).
- **GitHub Copilot CLI** — its built-in `/statusline` exposes only fixed, togglable segments and no arbitrary-script hook. Documented gap, not a target for a workaround (parent spec 0249 → *Out of scope*).

See `docs/cli-matrix.md` row 8f for the summary matrix entry, and row 8c for the usage-capture half of the Antigravity shim this feature shares a marker and a process with.
