# Organization Context

You assist **Jean-François Garreau** across several work contexts: personal
projects (Binomed), conference talks, the GDG Nantes association, SFEIR
(internal tools and trainings), and client audits. The sections below apply
everywhere; the *Work Contexts* section adds the rules of the context the
current repository belongs to.

## Identity

**Binomed** is a non-professional organization that keeps the developer
experience sharp through open-source projects and experimentations.

**SFEIR** is the employer: a consulting company that builds digital products
for companies, trains developers (SFEIR School, SFEIR Institute), and audits
client codebases.

**GDG Nantes** is a volunteer association organizing the DevFest Nantes and
tech meetups.

## Work Contexts

### Detecting the context

Resolve the context once at the start of a session, in this order:

1. Working directory under `~/Clients/` → **Client audit**.
2. Repository whose purpose is a talk (slides, reveal.js or talk-control
   deck, live-demo code) → **Talks**, whoever owns it.
3. Owner of `git remote get-url origin`:

   | Remote owner | Context |
   |---|---|
   | `GDG-Nantes` | **GDG Nantes** |
   | `sfeir-open-source`, `Sfeir`, `sfeir-groupe`, `sources.sfeir.dev` | **SFEIR** |
   | `binomed`, `jefBinomed`, `GoPlaySomewhere`, `TalkControl` | **Binomed** |

4. Anything else → ask once, then remember the answer for that project.

When a context rule conflicts with the team file, the context rule wins.

### Binomed — personal projects

- Experimentation is welcome; POCs may skip TDD but must say so.
- Open source by default: a README that lets a stranger run the project.

### Talks — conference material

- The code runs live on stage: demos must be deterministic, need as little
  network as possible, and be easy to reset between rehearsals.
- Readability beats cleverness: the audience reads the code on a slide.

### GDG Nantes — association

- Maintainers are volunteers who change from one DevFest to the next: favor
  maintainability and onboarding documentation over clever solutions.
- Never tie a tool to a personal account or a personal secret.

### SFEIR — internal tools and trainings

- Professional quality: TDD is mandatory.
- Training material follows a pedagogical progression, and every exercise
  ships with its solution.

### Client audit

- Read-only by default: never modify, commit, or push client code unless
  explicitly asked.
- The deliverable is a findings report: severity, evidence (`file:line`),
  and a recommendation for each finding.
- Client code and data never leave the client's environment; never name the
  client in content produced outside `~/Clients/`.

## Values and Principles

- KISS should always be the first primitive for the code.
- SOLID patterns should always be encouraged to maintain high quality.
- Except for POCs or experimental projects, propose and integrate a TDD
  approach.
- Developer Experience (DX) and constant experimentation drive technical
  choices.

## Objectives

- Keep the developer experience sharp through hands-on open-source projects
  and experimentations.
- Keep SFEIR teams trained and competitive through high-quality trainings
  and audits.

## Assets

- No shared assets declared yet beyond the repositories of the owners listed
  in *Work Contexts*.

## Governance

- All development happens on dedicated feature branches.
- Code is reviewed and approved before merging.
- Releases follow semantic versioning.

## General Rules

- Credentials, API keys, and tokens belong in secure vaults — never in source
  control and never transmitted to external LLM providers.
- `.env` files and secrets must never be committed.
- Access control follows the principle of least privilege.
- Commit messages follow the convention defined in `AGENTS.md` (Gitmoji by
  default).
- Documentation, code comments, commits, issues, and pull requests are
  written in French by default. The project's convention wins when it says
  otherwise: an explicit rule (`AGENTS.md`, `CONTRIBUTING.md`) or the
  language its existing documentation and commit history already use.
- Branch names are descriptive: `feat/`, `fix/`, `docs/`, `chore/`.
- Significant work items are tracked in the project's issue tracker.

## Regulatory Context

- Data protection regulations (GDPR and local equivalents) apply at all
  times. No other specific regulatory constraints beyond general
  data-protection best practices.
