---
id: "org-0001"
slug: kernel-extension
status: approved
complexity: small
interaction-mode: INTERMEDIATE
related-issue: 2
version: 1.0.0
---

# Package the kernel skill as a CrewRig extension

## Intent

A person invoking the kernel prompt-engineering helper gets the identical
guided interview and final structured prompt their existing personal,
machine-local setup already provides, but reachable through CrewRig's own
installable, versioned delivery path — the same way any other CrewRig
extension is installed and invoked — instead of living as a file outside
the framework that only works on the one machine it was placed on.

## Requirements

1. The repository SHALL declare a CrewRig extension named `kernel` under
   `extensions/org/kernel/` (the org tier — adopter-owned, excluded from
   the upstream synchronization).
2. The extension's manifest SHALL declare exactly one generic declaration
   subject, `skills`, with `location: "skills/"`; the manifest SHALL
   declare no `mcpServers` section, no `commands` section, no `agents`
   section, and no `hooks` section.
3. The shipped skill's frontmatter `description` and body SHALL be
   content-equivalent to the existing personal kernel skill (same
   interview behavior, same explicit-invocation-only framing, same
   six-principle method) — reusing the established, already-working
   workflow rather than rewriting it.
4. The skill SHALL remain invokable by name wherever a supported
   command-line tool invokes a skill directly by its declared name
   (confirmed behavior today); the extension SHALL NOT introduce a
   separate slash-command pivot file for this capability.
5. The extension SHALL declare an agent-facing context source describing
   the skill's availability and purpose, rendered per target per the
   extension format's context-rendering contract.
6. A full render of the extension for every supported command-line tool
   SHALL complete with zero observed, undeclared gaps; the extension
   SHALL ship no gap-acceptance file.
7. If a render of the extension for any supported command-line tool
   produces a warning for an unmappable declaration, that render SHALL be
   treated as a failing precondition for merging this ticket's
   implementation pull request — no gap-acceptance entry SHALL be added
   to paper over it; the declaration causing the warning SHALL instead be
   corrected.
8. The extension SHALL be installable through the standard delivery path
   with no extension-specific installation step beyond what the
   repository's existing install tooling already provides for any other
   skill-only extension.
9. The extension's package manifest SHALL declare no runtime dependency
   beyond what the base extension scaffold already provides, since the
   extension ships no server component of its own.

## Scenarios

**Scenario:** Happy path — skill-only extension renders and installs cleanly

Given the `kernel` extension is declared under `extensions/org/kernel/`
with only a `skills` declaration subject and a context source
When the extension is rendered for all four supported command-line tools
Then the render completes successfully, produces no observed gap for any
target, and the built Claude Code form contains a `kernel` skill whose
content is equivalent to the existing personal kernel skill

**Scenario:** Failure path — an unmappable declaration surfaces a gap

Given a future edit to the `kernel` extension's context source references
an undeclared command or skill entry, or a future declaration subject
maps incompletely on one of the four supported command-line tools
When the extension is rendered with gap-checking enabled
Then the render fails loudly, naming the offending file and the affected
target, rather than silently producing a degraded extension, and this
ticket's implementation pull request SHALL NOT merge until the render is
clean

## Out of scope

- Any slash-command pivot for the kernel capability — the skill's
  existing name-based invocation is kept as-is.
- Any server component for the `kernel` extension — the skill is pure
  prompt-engineering guidance with no external tool calls.
- Contributing this extension upstream to the reference CrewRig
  repository — the org tier is explicitly excluded from the upstream
  synchronization.
- Changes to the existing personal kernel skill file itself, which lives
  outside this repository.
- Changes to the shared extension scaffolding or render tooling.

## Open questions

(none — resolved during the SPECS-stage interview)
