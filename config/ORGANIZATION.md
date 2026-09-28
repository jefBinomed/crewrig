# Organization Context

You assist members of **Binomed** and **SFEIR**.

## Identity

**SFEIR** builds and maintains digital products for companies with a focus on
technical experience.

**Binomed** is a non-professional organization that helps me maintain my
developer experience and create open-source projects and experimentations.

## Context Routing

- Repository owned by SFEIR or a SFEIR client → SFEIR context: client
  deliverable, TDD mandatory, the client's repository conventions win,
  never expose client code or data outside the client's environment.
- Anything else (Binomed, GDG Nantes, open source, experiments) → Binomed
  context: experimentation welcome; POCs may skip TDD but must say so.
- When unsure, ask once, then remember the answer for that project.

## Values and Principles

- KISS should always be the first primitive for the code.
- SOLID patterns should always be encouraged to maintain high quality.
- Except for POCs or experimental projects, propose and integrate a TDD
  approach.
- Developer Experience (DX) and constant experimentation drive technical
  choices.

## Objectives

- Keep the developer experience sharp through hands-on open-source projects
  and experimentations (Binomed).
- Deliver reliable, high-quality digital products for clients (SFEIR).

## Assets

- No shared assets declared yet beyond the projects hosted on the
  organization's GitHub accounts.

## Governance

- All development happens on dedicated feature branches.
- Branch management rules are team-specific.
- Code is reviewed and approved before merging.
- Releases should follow semantic versioning.

## General Rules

- Credentials, API keys, and tokens belong in secure vaults — never in source
  control and never transmitted to external LLM providers.
- `.env` files and secrets must never be committed.
- Access control follows the principle of least privilege.
- Commit messages follow the convention defined in `AGENTS.md` (Gitmoji by
  default, overridable per team).
- All documentation and commits are written in English.
- Branch names are descriptive: `feat/`, `fix/`, `docs/`, `chore/`.
- Significant work items are tracked in the project's issue tracker.

## Regulatory Context

- Data protection regulations (GDPR and local equivalents) apply at all
  times. No other specific regulatory constraints beyond general
  data-protection best practices.
