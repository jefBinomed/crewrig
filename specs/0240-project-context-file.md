---
id: "0240"
slug: project-context-file
status: approved
complexity: small
interaction-mode: INTERMEDIATE
related-issue: 1367
version: 1.0.0
---

# Project-local context and team declaration file

## Intent

A person who works across several projects tied to different work contexts
(Binomed, Talks, GDG Nantes, SFEIR, Client audit) and different team
profiles notices that opening a session in any given project immediately
and consistently applies that project's own context and team, without
being asked and without silently relying on a prior answer the person
cannot see, diff, or carry to another machine — an explicit, project-local
file now settles the question the same way for every session and every
tool, ahead of the existing detection heuristics.

## Requirements

1. The context-resolution procedure in `config/ORGANIZATION.md` →
   *Detecting the context* SHALL check for a project-local
   context-declaration file at the repository root before evaluating any
   of the four existing heuristics (working directory under
   `~/Clients/`, talk-repository shape, remote-owner table,
   ask-once-and-remember).
2. Two tiers of context-declaration file SHALL exist at the repository
   root: `.crewrig-context`, a project-owned artifact intended to be
   committed to the repository, and `.crewrig-context.local`, a
   personal-override artifact never committed. The two-tier split and
   both filenames are a deliberate departure from the raw `.crewrig`
   name floated in the originating issue: the repository already uses a
   `.crewrig/` *directory* for framework-governance state
   (`core-paths.txt`, `spec-id-carrier`, per `docs/adoption-guide.md`),
   and a file and a directory cannot share one name in the same
   location — `.crewrig-context` and `.crewrig-context.local` avoid the
   collision entirely rather than depending on the two never coexisting
   in the same repository.
3. When `.crewrig-context.local` is present at the repository root, its
   declared context (and team, if declared) SHALL be authoritative for
   the session, and neither `.crewrig-context` nor the four existing
   heuristics SHALL be evaluated.
4. When `.crewrig-context.local` is absent but `.crewrig-context` is
   present at the repository root, its declared context (and team, if
   declared) SHALL be authoritative for the session, and the four
   existing heuristics SHALL NOT be evaluated.
5. When neither `.crewrig-context.local` nor `.crewrig-context` is
   present at the repository root, the four existing heuristics SHALL
   run unchanged, in their existing order, exactly as before this spec.
6. A context-declaration file SHALL express its content as a small set
   of `key: value` lines: a required `context:` line, and an optional
   `team:` line. A file present at the repository root but containing
   no recognizable `context:` line SHALL be treated as absent for the
   purpose of Requirements 3-5, and the session SHALL fall through to
   the next tier (or to the existing heuristics) rather than stall or
   apply a guessed value.
7. The `context:` value SHALL be one of the five values named by the
   `### <name>` subsection headers under `config/ORGANIZATION.md` →
   *Work Contexts* (Binomed, Talks, GDG Nantes, SFEIR, Client audit,
   expressed as slugs). A `context:` value outside this set SHALL be
   treated the same as a missing `context:` line under Requirement 6.
8. The `team:` value, when present, SHALL name an existing file under
   `config/teams/` (its basename without the `.md` extension). A
   declared `team:` value SHALL be honored even when it is not the team
   conventionally associated with the declared `context:` value —
   `context:` and `team:` in a context-declaration file MAY diverge,
   consistent with `config/ORGANIZATION.md` line 40 already treating
   context and team as two axes that can independently conflict.
9. A declared `team:` value that does not name an existing file under
   `config/teams/` SHALL NOT silently be dropped: the session SHALL
   still apply the declared `context:` normally, SHALL surface that the
   `team:` value did not resolve, and SHALL fall back to whatever team
   resolution would have applied had `team:` been absent.
10. When a context-declaration file's `team:` value is authoritative for
    a session (Requirements 3, 4, 8), the session SHALL apply the
    content of the corresponding `config/teams/<team>.md` file for that
    session, regardless of which single team file was deployed to the
    machine's static priority-layer team file (e.g.
    `~/.claude/rules/50-team.md`) at setup time. This is the requirement
    that actually answers the originating issue: today's team selection
    is a one-time, whole-machine choice made by the interactive setup
    script, which is precisely why working across several
    differently-teamed projects in parallel is impractical without it.
11. A context-declaration file SHALL be resolved only at the git
    top-level directory of the current repository — the same repository
    root already used to derive `<project-name>` in
    `artifacts/core/system-context/palace-structure-conventions.md` →
    *Project name derivation*. A context-declaration file placed
    anywhere else in the repository tree SHALL have no effect.
12. `.crewrig-context.local` SHALL never be committed to version
    control: an adopter repository already tracking a `.gitignore` SHALL
    exclude `.crewrig-context.local` from it. `.crewrig-context` SHALL
    remain a normal trackable, committable file with no default
    exclusion.
13. When the ask-once-and-remember heuristic (the fourth and last-resort
    existing heuristic) fires and the person answers, the session SHALL
    offer to persist that answer into a context-declaration file at the
    repository root — the person choosing between the committed tier
    (`.crewrig-context`) and the personal-override tier
    (`.crewrig-context.local`), or declining. Declining SHALL leave the
    existing MemPalace-backed ask-and-remember behavior unchanged for
    that project; this requirement is additive to that fallback, not a
    replacement of it.

## Scenarios

**Scenario:** Committed context file resolves a client-audit repository

Given a project repository whose root contains a committed
`.crewrig-context` file with `context: client-audit`
When a new agent session starts in that repository
Then the agent applies the Client audit context rules directly, without
evaluating the working-directory, talk-shape, or remote-owner heuristics
and without asking the person

**Scenario:** Personal override takes precedence over the committed file

Given a repository root containing both a committed `.crewrig-context`
file with `context: sfeir` and a gitignored `.crewrig-context.local`
file with `context: binomed`
When a new agent session starts in that repository
Then the agent applies the Binomed context declared by
`.crewrig-context.local`, not the SFEIR context declared by the
committed file

**Scenario:** Declared team diverges from the declared context's usual team

Given a repository's `.crewrig-context` file declares `context:
client-audit` and `team: atlas`
When a new agent session starts in that repository
Then the agent applies the Client audit context rules together with the
`config/teams/ATLAS.md` team profile for that session, even though Atlas
is not the team conventionally associated with Client audit work

**Scenario:** Malformed context file falls through instead of guessing

Given a repository root `.crewrig-context` file whose content contains
no recognizable `context:` line
When a new agent session starts in that repository
Then the agent SHALL NOT apply a guessed or partial context from that
file, and SHALL fall through to `.crewrig-context.local` if present, or
otherwise to the four existing heuristics, exactly as if the malformed
file were absent

**Scenario:** Unresolvable team value warns without discarding the context

Given a `.crewrig-context` file declares `context: sfeir` and `team:
nonexistent-team`, and no file named `config/teams/nonexistent-team.md`
exists
When a new agent session starts in that repository
Then the agent applies the SFEIR context normally, surfaces that
`nonexistent-team` did not resolve to an existing team file, and falls
back to the team resolution that would have applied had `team:` been
absent

## Out of scope

- The concrete implementation of the file-detection and file-parsing
  logic (shell snippet, script, or inline agent instruction wording)
  added to `config/ORGANIZATION.md` — this spec fixes the WHAT and the
  precedence; the HOW belongs to the PLAN stage.
- Any change to the internal logic or relative order of the four
  existing heuristics — this spec only inserts two new, higher-priority
  checks ahead of the unchanged existing chain.
- Sub-project or monorepo-scoped overrides (a context-declaration file
  read from anywhere other than the git top-level). Requirement 11
  fixes single-file, repository-root resolution only.
- Changing the storage or retrieval mechanism of the existing
  MemPalace-backed ask-and-remember fallback itself. Requirement 13
  only adds an offer to persist the answer as a file; the underlying
  fallback mechanism is untouched.
- Renaming or restructuring the existing `.crewrig/` directory used for
  framework-governance state (`core-paths.txt`, `spec-id-carrier`).
  Requirement 2 resolves the naming collision by choosing a different
  filename instead.
- Schema validation or linting of context-declaration files in CI (a
  spec-linter-style checker analogous to `scripts/lib/spec-linter.js`).
  Left to a follow-up ticket if the person wants it.
- Any change to how `config/teams/*.md` files are authored (the
  `init-team` skill) or to the interactive setup scripts' one-time,
  whole-machine team deployment (`50-team.md`) itself — this spec adds
  a per-project override on top of that deployment (Requirement 10), it
  does not remove or restructure the deployment mechanism.

## Open questions

- **Commit or not (resolved as a recommendation, pending SPECS-stage
  confirmation).** Requirements 2-5 and 12 already encode the two-tier
  `.crewrig-context` (committed) / `.crewrig-context.local` (gitignored)
  design suggested in the originating brief, with the precedence
  `.crewrig-context.local` > `.crewrig-context` > the four existing
  heuristics (working-directory, talk-shape, remote-owner,
  ask-and-remember) unchanged among themselves. This is a genuine design
  choice, not a fact derivable from the codebase — it should be
  explicitly confirmed (not just tacitly accepted) at this spec's
  SPECS-stage content-approval gate before the spec-PR merges.
- **Scope: context, team, or both (resolved as a recommendation, pending
  SPECS-stage confirmation).** Requirements 6-10 already encode "both,
  with permitted divergence" — a required `context:` field plus an
  optional `team:` field that need not match the context's conventional
  team. The alternative (context-only, deferring team selection to a
  later ticket) would be simpler to implement but would leave
  Requirement 10 — the requirement that actually answers the
  originating issue's per-project team complaint — unaddressed. Same
  confirmation-before-merge status as the item above.
