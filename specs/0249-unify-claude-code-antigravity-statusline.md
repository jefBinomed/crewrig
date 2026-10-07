---
id: "0249"
slug: unify-claude-code-antigravity-statusline
status: draft
complexity: standard
interaction-mode: AUTO
related-issue: 4
version: 1.0.0
---

# Unify Claude Code and Antigravity CLI statusline rendering

## Intent

A user running both Claude Code and Antigravity CLI sees two status lines
that look and behave differently from each other, even though both lines
show comparable information — the active model, the current working
directory, and cost or token usage when the host CLI reports it. This
specification makes the two CLIs' status lines visually and behaviorally
consistent with each other, so a user who switches between them recognizes
the same line layout, field order, and visual styling, without changing
what information either CLI is able to supply on its own. Antigravity
CLI's existing status-line usage-capture behavior continues to work
unchanged alongside this new, consistent appearance. Gemini CLI and GitHub
Copilot CLI are not affected.

## Requirements

1. For every field reported by both Claude Code's and Antigravity CLI's
   native status payload — at minimum the active model identifier, the
   current working directory or project root, and cost/token usage when
   the host CLI reports it — the two CLIs' rendered status lines SHALL
   present that field in the same order, the same formatted
   representation, and the same visual (ANSI) styling.
2. The status-line rendering step SHALL NOT spawn an additional
   subprocess (a `git` invocation, a shell-out, or any similarly
   expensive operation) beyond what the host CLI's own native payload
   already supplies, on either CLI. This bounds the cost of a step that
   can run many times per turn — Antigravity CLI's statusline channel
   alone is documented to fire up to ten times for a single `agy -p`
   invocation — without committing to a measured latency budget.
3. When a CLI's native payload does not report a field included in the
   shared layout, the rendered status line SHALL omit that field's
   position rather than show a placeholder, an error indicator, or any
   other stand-in content; omission is the expected, non-error outcome.
4. When a CLI's native payload is missing, empty, or does not parse as
   the expected shape, the rendering step SHALL apply the same
   omission treatment to every field it cannot derive from that
   payload, rather than treating the condition as fatal.
5. Claude Code's status-line integration SHALL be installed through the
   `statusLine` key of its deployed `settings.json`, and SHALL NOT depend
   on any status-line declaration mechanism exposed by a Claude Code
   plugin, since no such mechanism exists today.
6. Installing the status-line integration on either CLI — the
   `statusLine` key on Claude Code, the `statusLine.command` key on
   Antigravity CLI — SHALL touch only the statusline-related key(s) it
   owns in that CLI's settings file. Every other key already present in
   that file — `permissions`, any registered `hooks` entries, any
   registered `mcpServers` entries, or any other key, named in this
   specification or not — SHALL remain completely unchanged.
7. When a user's settings file already carries a statusline value (the
   `statusLine` key on Claude Code, the `statusLine.command` key on
   Antigravity CLI) that this framework did not install, the installer
   SHALL show the user a preview of that existing value and of the
   value that would replace it, and SHALL let the user explicitly
   choose whether to keep the existing value or replace it with the
   unified integration, rather than silently refusing installation and
   only reporting that it was not applied.
8. In plain terms: turning the unified rendering on or off must not
   change whether, or how, Antigravity's usage-capture forwarding runs.
   Enabling the unified status-line rendering SHALL NOT change whether
   the usage-capture adapter runs, nor what native payload content it
   receives, for any invocation where usage capture is separately
   enabled: the adapter SHALL continue to receive the complete,
   unaltered native status-line payload it would receive with rendering
   disabled.
9. In plain terms: a problem in one of the two things
   `statusLine.command` now does on Antigravity CLI — rendering the
   display, or forwarding the payload for usage capture — must not take
   the other one down with it. A failure in the status-line rendering
   step SHALL NOT prevent the usage-capture forwarding step from
   completing, and a failure in the usage-capture forwarding step SHALL
   NOT prevent the rendered status line from reaching stdout; each
   step's failure SHALL be contained to that step.
10. In plain terms: whatever goes wrong while rendering — a missing
    field, a malformed payload, anything else — the status-line command
    itself must still finish cleanly rather than crash or report an
    error. On either CLI, the rendering step SHALL NOT raise an
    unhandled error and SHALL NOT cause a non-zero exit on account of a
    missing, malformed, or absent native payload, or any individual
    field the payload does not report. On Antigravity CLI specifically,
    the combined `statusLine.command` process SHALL exit zero regardless
    of the outcome of the rendering step or the usage-capture forwarding
    step, preserving the existing contract that a display-command
    failure never surfaces to the user as a broken status line.
11. Re-running the installation of either CLI's status-line integration
    after it has already been applied SHALL NOT duplicate the
    integration or silently discard a since-changed native value; it
    SHALL offer to keep the existing installation or remove it,
    restoring whatever value preceded installation.
12. When the active model, working directory, or cost/token fields
    change between invocations, the rendered status line SHALL reflect
    the new values on the next invocation; it SHALL NOT display a cached
    value from an earlier invocation.
13. Gemini CLI's configuration and GitHub Copilot CLI's configuration
    SHALL NOT be modified by any requirement in this specification.
14. The rendering behavior common to both CLIs SHALL be verifiable by at
    least one automated check that feeds the same normalized field set
    through each CLI's integration and asserts identical rendered output
    for the fields both CLIs support.
15. The implementation effort for this specification SHALL update
    `docs/cli-matrix.md` with a new row, or an update to an existing
    row, documenting this status-line integration point, per `AGENTS.md`
    → *CLI Matrix Maintenance*. This update lands at the DEV stage of
    the lifecycle, not as part of this specification.

## Scenarios

**Scenario:** Consistent rendering across both CLIs

Given a user has the unified status-line integration installed on both
Claude Code and Antigravity CLI, and both CLIs report an active model, a
working directory, and a cost/token figure in their native payload
When  each CLI invokes its configured status-line command
Then  both CLIs display a status line presenting the model, the working
      directory, and the cost/token figure in the same order, the same
      formatting, and the same visual styling

**Scenario:** Missing field is omitted rather than forced into a placeholder

Given Claude Code's native payload omits cost/token data because cost
tracking is disabled
When  Claude Code invokes its status-line command
Then  the rendered status line omits the cost/token position entirely,
      with no placeholder or error indicator shown in its place

**Scenario:** Malformed payload yields omitted fields, not a crash

Given the status-line command receives a payload that does not parse as
the expected shape
When  the command runs
Then  it exits zero and omits every field it cannot derive from that
      payload, instead of raising an error or producing a non-zero exit

**Scenario:** Rendering composes with usage-capture forwarding without
racing it

Given Antigravity CLI has both usage-capture enabled (forwarding the
native payload to the capture adapter) and the unified status-line
rendering enabled
When  Antigravity CLI invokes its `statusLine.command`
Then  the usage-capture adapter receives the complete, unaltered native
      payload exactly as it would without rendering enabled, stdout
      carries the rendered (not raw-passthrough) status line, and the
      process exits zero

## Out of scope

- Gemini CLI — no `statusLine`-equivalent hook exists in its settings
  schema or extension manifest today. This is a documented gap, not a
  target for a workaround.
- GitHub Copilot CLI — its built-in `/statusline` exposes only fixed,
  togglable segments and no arbitrary-script hook. This is a documented
  gap, not a target for a workaround.
- Any change to `hooks/antigravity-transcript-hooks.json` or the
  session-recording / transcript-hook manifests on any CLI — untouched
  by this specification.
- Any change to the usage-capture adapters' field derivation, cursor
  semantics, or record schema (spec 0206, spec 0207, and related specs)
  — this specification composes rendering with the existing forwarding
  behavior; it does not alter capture derivation.
- A user-configurable theming or segment-selection surface for the
  status line — this specification establishes one consistent default
  appearance, not a configuration surface for customizing it further.
- Windows-specific ANSI-rendering differences — this specification does
  not address platform-specific terminal-rendering variance; any such
  gap belongs to the general cross-platform tracking already underway
  in `docs/cli-matrix.md`, not to this effort.
- Fixing the spec-id reservation tool's fork-topology behavior — a
  separate, already-filed issue, unrelated to this ticket (see the
  corresponding entry in *Open questions* for what was observed while
  securing this spec's own id).

## Open questions

- [GROUNDING:] `config/claude/settings.json.template`, read on this
  branch, currently contains only a `permissions` key — no `hooks` or
  `mcpServers` key is present in the committed template file itself.
  Requirements 6 and 7 are worded against the deployed
  `~/.claude/settings.json` (the end state after setup-script merges),
  not against the static template file, so they hold either way; PLAN
  should confirm which installer code path (template vs. a setup-script
  merge, mirroring the pattern `scripts/lib/usage-capture-optin.sh`
  already uses for hooks) is the right place to add the `statusLine`
  key.
- [USER-PARKED] The concrete visual styling target (color treatment,
  field ordering, separators, spacing around an omitted field) is
  deliberately left unspecified at this WHAT-level stage. JF confirmed
  PLAN should spend real design time taking inspiration from
  established statusline conventions — common community Claude Code
  statuslines, Starship-prompt-style segment formatting — before fixing
  the concrete layout, rather than designing the exact styling from
  scratch in isolation.
- [AUTO-PARKED] While securing this spec's id, both `refs/spec-ids/0241`
  and `refs/spec-ids/0249` were found on the `origin` remote, each
  carrying a reservation commit reading "reserve `<id>` for issue #4".
  This draft was authored under id 0249 per the explicit id already
  assigned to this ticket's branch and worktree; the duplicate
  reservation is consistent with the already-filed, out-of-scope
  fork-topology bug in `scripts/reserve-spec-id.sh` and was not
  investigated or fixed here. Recording it so whoever closes that
  separate bug has the evidence, rather than rediscovering it as an
  apparent data inconsistency.
- [AUTO-PARKED] No interaction mode was declared on the originating
  ticket. Per `docs/interaction-modes.md`, the framework default is
  INTERMEDIATE, which requires an `AskUserQuestion`-style interview
  turn per question during authoring. This authoring session had no
  such interactive tool available (a subagent with no user-facing
  question channel), so the draft was produced end-to-end without an
  interview round-trip — the shape AUTO mode describes — and the
  frontmatter records `interaction-mode: AUTO` to match what actually
  happened rather than overclaiming an interview that did not occur.
  The SPECS-stage content-approval gate has not run on this draft; it
  should be run as a normal ungated AUTO-mode draft, not treated as
  already interviewed.
