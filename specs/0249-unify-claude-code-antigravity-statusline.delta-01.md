---
id: "0249"
slug: unify-claude-code-antigravity-statusline
status: approved
complexity: standard
interaction-mode: AUTO
related-issue: 4
version: 2.0.0
---

# Unify Claude Code and Antigravity CLI statusline rendering

A PLAN-stage design review on issue #4 (two APPROVE'd plan revisions already
spent) surfaced that the original specification's architecture no longer
matches reality: Claude Code already has a rich, actively-used, separately
maintained statusline tool (`ccstatusline`) wired into the user's own
`settings.json`; Antigravity CLI's native `statusLine.command` payload is
far richer than the original spec's grounding captured, including VCS branch
and dirty-state fields at zero subprocess cost; and the user already runs a
personal Antigravity statusline script that computes a cost estimate from
token counts, which the original spec's Alternative #3 had rejected
outright. This delta replaces the shared-renderer, byte-identical-output
architecture with CLI-appropriate install/wrap requirements: CrewRig ensures
`ccstatusline` is installed and configured for Claude Code, and installs a
CrewRig-enhanced version of the user's own script for Antigravity CLI. The
complexity tier is reconfirmed as `standard` (unchanged from the original
spec): the change set still spans two setup-script install paths, a
third-party-dependency check, an enhanced personal script, new bounded-cost
caching behavior, and doc updates, which is less net-new code than the
original shared-renderer design but not small enough to re-tier.

## ADDED

### Requirements

The requirements extend the parent's `## Requirements` list (new numbers 16
to 19; numbers 1-15 are the parent's, modified or removed as shown below).

**Requirement 16.** Claude Code's status-line integration SHALL ensure
`ccstatusline` is installed before wiring the `statusLine` key to invoke it,
but, when `ccstatusline` is already installed and already carries the
user's own segment configuration at its own settings location, the
installer SHALL NOT overwrite or reset that configuration, and SHALL wire
the `statusLine` key to invoke it only when that key is not already pointed
at it.

**Requirement 17.** Antigravity CLI's status-line integration MAY render a
computed cost figure derived from the native payload's token-count fields
combined with a maintained per-model pricing table, PROVIDED the rendered
figure is visually distinguished from a CLI-natively-reported cost figure as
an estimate — never presented identically to a native, non-estimated
figure. When the active model has no entry in the pricing table, the
integration SHALL omit the computed cost figure rather than render a zero,
a placeholder, or an unlabeled guess.

**Requirement 18.** When Antigravity CLI's native payload reports
`vcs.branch` or `vcs.dirty`, the Antigravity integration SHALL be able to
present that information without spawning a subprocess to obtain it;
Requirement 2's no-extra-subprocess rule is not implicated by rendering
these two fields, since the host CLI already supplies them. When the native
payload omits `vcs` entirely (for instance, outside a version-controlled
working directory), the integration SHALL omit the VCS fields per
Requirement 3's existing omission contract, rather than fall back to a
subprocess to derive them.

**Requirement 19.** When the Antigravity integration derives a working-tree
change count (or a similarly-costed value) via a subprocess that
Requirement 2 would otherwise forbid, that subprocess invocation SHALL be
bounded by a caching mechanism that avoids re-invoking it on every
status-line firing; this specification does not prescribe the cache's TTL
or storage form, leaving that choice to the PLAN stage. When the
subprocess fails, times out, or the cache cannot be read or written for any
reason, the integration SHALL omit the change-count field rather than
raise an error or prevent the rest of the status line from rendering, per
Requirement 4's existing malformed/missing-data contract.

### Scenarios

**Scenario:** ccstatusline is installed when absent

Given a user enables CrewRig's Claude Code status-line integration and
`ccstatusline` is not currently installed
When  the installer runs
Then  it installs `ccstatusline`, wires the `statusLine` key to invoke it,
      and leaves no other key in `settings.json` modified

**Scenario:** An existing ccstatusline configuration is left untouched

Given a user already has `ccstatusline` installed with their own customized
segment configuration, and `settings.json`'s `statusLine` key already
invokes it
When  the installer runs again
Then  it makes no change to the user's `ccstatusline` configuration or to
      the `statusLine` key

**Scenario:** Antigravity renders a labeled cost estimate

Given Antigravity CLI's native payload reports token counts for a model
present in the pricing table, and no native cost field exists in that
payload
When  the Antigravity status-line integration renders
Then  it displays a computed cost figure visually distinguished as an
      estimate, never presented as if it were a CLI-native, non-estimated
      figure

**Scenario:** VCS branch and dirty state render without a subprocess

Given Antigravity CLI's native payload reports `vcs.branch` and `vcs.dirty`
for the current working directory
When  the Antigravity status-line integration renders
Then  it displays the branch name and dirty-state indicator using only the
      native payload's fields, without spawning a `git` subprocess

**Scenario:** Cost estimate omitted when the pricing table has no entry
(failure path)

Given Antigravity CLI's native payload reports token counts for a model that
is absent from the maintained pricing table
When  the Antigravity status-line integration renders
Then  it omits the cost-estimate position entirely, with no zero value,
      placeholder, or unlabeled guess shown in its place

**Scenario:** Change-count subprocess failure does not break rendering
(failure path)

Given the Antigravity integration's bounded-cost subprocess for the
working-tree change count fails, times out, or its cache cannot be read or
written
When  the status-line command runs
Then  it omits the change-count field, renders every other field normally,
      and exits zero

### Out of scope

- `ccstatusline`'s own internal rendering logic, configuration schema, or
  upstream maintenance — CrewRig only ensures its installation and wires the
  `statusLine` key to invoke it; CrewRig does not fork, vendor, or patch
  `ccstatusline` itself.
- The exact visual layout of the CrewRig-enhanced Antigravity statusline
  script (segment order, color choices, context-bar rendering style) — left
  to the PLAN stage, consistent with the original specification's existing
  deferral of concrete styling detail.
- The maintained per-model pricing table's exact figures, update cadence, or
  source of truth — left to the PLAN and DEV stages; this delta only
  requires that a labeled estimate be possible (Requirement 17), not what
  the table contains or how it is kept current.
- The exact caching mechanism, storage location, or TTL value for the
  working-tree change-count subprocess (Requirement 19) — a HOW-level
  choice left to the PLAN stage.
- A native (CLI-reported, non-estimated) dollar-cost field or a
  thinking-effort-equivalent indicator for Antigravity CLI — confirmed
  absent from its documented native payload schema across three
  independently cross-checked sources (the official docs, an
  independently-read third-party statusline script, and the user's own
  existing personal script). Requirement 17's computed estimate remains
  this specification's only cost mechanism for that CLI; no requirement in
  this specification or a future delta should assume a native field will
  appear without new, independent grounding.

### Open questions

- [RESOLVED, user-validate pass 1] Whether Claude Code's installer should
  ever proactively upgrade `ccstatusline`'s installed *package version* on a
  reinstall. JF's answer: no — CrewRig manages the `statusLine` wiring and
  leaves the installed package version entirely alone once present; version
  management may be revisited in a future ticket, not this one. PLAN SHALL
  NOT introduce a version-bump mechanism for `ccstatusline`.
- [RESOLVED, user-validate pass 1] Whether re-running the Antigravity
  installer should preserve a user's hand-edits to the CrewRig-installed
  enhanced statusline script. JF's answer: no — the script is fully
  CrewRig-owned; the user is not expected to hand-edit it outside CrewRig's
  own install/upgrade path. PLAN and DEV may treat Requirement 11's existing
  reinstall contract (offer keep/remove, restore prior value) as sufficient
  for this file without a `ccstatusline`-style configuration-preservation
  carve-out.
- The parent's own `## Open questions` bullets (the `[GROUNDING:]`,
  `[USER-PARKED]`, and `[AUTO-PARKED]` entries recorded at the original
  spec's authoring time) remain as historical record and are unaffected by
  this delta.

## MODIFIED

1. **`## Intent`.**

   Original:

   > A user running both Claude Code and Antigravity CLI sees two status
   > lines that look and behave differently from each other, even though
   > both lines show comparable information — the active model, the
   > current working directory, and cost or token usage when the host CLI
   > reports it. This specification makes the two CLIs' status lines
   > visually and behaviorally consistent with each other, so a user who
   > switches between them recognizes the same line layout, field order,
   > and visual styling, without changing what information either CLI is
   > able to supply on its own. Antigravity CLI's existing status-line
   > usage-capture behavior continues to work unchanged alongside this new,
   > consistent appearance. Gemini CLI and GitHub Copilot CLI are not
   > affected.

   Replacement:

   > A user running both Claude Code and Antigravity CLI sees two status
   > lines that look and behave differently from each other, even though
   > both lines show comparable information — the active model, the
   > current working directory, VCS state, and cost or an estimated cost
   > when either CLI can supply or derive it. This specification makes the
   > two CLIs' status lines visually comparable in the information each
   > shows and in each line's attention to the same categories, while
   > relying on each CLI's own appropriate native-ecosystem tool to do the
   > rendering — the actively-maintained third-party `ccstatusline` tool on
   > Claude Code, and a CrewRig-enhanced version of Antigravity's own
   > statusline script on Antigravity CLI — rather than a single shared
   > renderer producing byte-identical output across both CLIs. Antigravity
   > CLI's existing status-line usage-capture behavior continues to work
   > unchanged alongside this new, consistent appearance. Gemini CLI and
   > GitHub Copilot CLI are not affected.

2. **Requirement 1.**

   Original:

   > For every field reported by both Claude Code's and Antigravity CLI's
   > native status payload — at minimum the active model identifier, the
   > current working directory or project root, and cost/token usage when
   > the host CLI reports it — the two CLIs' rendered status lines SHALL
   > present that field in the same order, the same formatted
   > representation, and the same visual (ANSI) styling.

   Replacement:

   > Claude Code's and Antigravity CLI's status lines SHALL each present,
   > using the native rendering tool this specification installs for that
   > CLI (Requirement 5 and Requirement 16), at minimum the active model
   > identifier, the current working directory or project root, and cost or
   > an estimated-cost figure when available — plus, on Antigravity CLI,
   > the VCS branch name and dirty-state fields its native payload reports
   > (Requirement 18). Cross-CLI parity is no longer a byte-identical-output
   > requirement: each CLI's status line is rendered by that CLI's own
   > appropriate tool, so the two lines MAY differ from each other in exact
   > field order, formatted representation, and visual styling, as long as
   > a user reading either line can identify the same categories of
   > information (model, location, VCS state, cost).

3. **Requirement 2.**

   Original:

   > The status-line rendering step SHALL NOT spawn an additional
   > subprocess (a `git` invocation, a shell-out, or any similarly
   > expensive operation) beyond what the host CLI's own native payload
   > already supplies, on either CLI. This bounds the cost of a step that
   > can run many times per turn — Antigravity CLI's statusline channel
   > alone is documented to fire up to ten times for a single `agy -p`
   > invocation — without committing to a measured latency budget.

   Replacement:

   > The status-line rendering step SHALL NOT spawn an additional
   > subprocess (a `git` invocation, a shell-out, or any similarly
   > expensive operation) beyond what the host CLI's own native payload
   > already supplies, on either CLI, EXCEPT for the one Antigravity-side
   > subprocess Requirement 19 permits (a bounded-cost, cached working-tree
   > change count) — which remains subject to Requirement 19's caching
   > obligation precisely because this requirement's no-extra-subprocess
   > rule would otherwise forbid it outright. This bounds the cost of a
   > step that can run many times per turn — Antigravity CLI's statusline
   > channel alone is documented to fire up to ten times for a single
   > `agy -p` invocation — without committing to a measured latency budget.

4. **Requirement 5.**

   Original:

   > Claude Code's status-line integration SHALL be installed through the
   > `statusLine` key of its deployed `settings.json`, and SHALL NOT depend
   > on any status-line declaration mechanism exposed by a Claude Code
   > plugin, since no such mechanism exists today.

   Replacement:

   > Claude Code's status-line integration SHALL be realized by ensuring
   > the third-party `ccstatusline` tool is installed and by wiring the
   > `statusLine` key of its deployed `settings.json` to invoke it, rather
   > than by installing a renderer this framework authors itself; the
   > installation SHALL still go through the `statusLine` key and SHALL NOT
   > depend on any status-line declaration mechanism exposed by a Claude
   > Code plugin, since no such mechanism exists today.

5. **Requirement 12.**

   Original:

   > When the active model, working directory, or cost/token fields change
   > between invocations, the rendered status line SHALL reflect the new
   > values on the next invocation; it SHALL NOT display a cached value
   > from an earlier invocation.

   Replacement:

   > When the active model, working directory, VCS state, or cost/token
   > fields change between invocations, the rendered status line SHALL
   > reflect the new values on the next invocation and SHALL NOT display a
   > cached value from an earlier invocation, EXCEPT for the one field
   > Requirement 19 explicitly permits to be served from a bounded cache
   > (the working-tree change count) during its cache window; every other
   > field remains subject to this requirement's no-stale-value rule
   > without exception.

6. **Scenario "Consistent rendering across both CLIs".**

   Original:

   ```text
   **Scenario:** Consistent rendering across both CLIs

   Given a user has the unified status-line integration installed on both
   Claude Code and Antigravity CLI, and both CLIs report an active model, a
   working directory, and a cost/token figure in their native payload
   When  each CLI invokes its configured status-line command
   Then  both CLIs display a status line presenting the model, the working
         directory, and the cost/token figure in the same order, the same
         formatting, and the same visual styling
   ```

   Replacement:

   ```text
   **Scenario:** Comparable rendering across both CLIs, via each CLI's own
   native tool

   Given a user has CrewRig's status-line integration installed on both
   Claude Code (wired to `ccstatusline`) and Antigravity CLI (wired to the
   CrewRig-enhanced statusline script), and both CLIs report an active
   model, a working directory, and a cost or cost-derivable figure in their
   native payload
   When  each CLI invokes its configured status-line command
   Then  both CLIs display a status line presenting the model, the working
         directory, VCS state where available, and a cost (native or
         estimated) figure — using each CLI's own native tool's layout,
         with no requirement that the two lines be byte-for-byte identical
         in order, formatting, or styling
   ```

## REMOVED

1. **Requirement 14** (the shared-renderer, byte-identical cross-CLI
   automated equivalence check):

   > The rendering behavior common to both CLIs SHALL be verifiable by at
   > least one automated check that feeds the same normalized field set
   > through each CLI's integration and asserts identical rendered output
   > for the fields both CLIs support.

   The shared-renderer premise this requirement assumed — a single
   normalized field set fed through one shared adapter pair — no longer
   holds now that each CLI is wired to its own distinct, separately
   maintained native-ecosystem tool (`ccstatusline` for Claude Code, the
   CrewRig-enhanced personal script for Antigravity CLI). No replacement
   equivalence check is introduced; Requirement 1 (as modified above) no
   longer makes a byte-identical-output claim for this check to verify.
