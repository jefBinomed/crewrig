# Organization Context

You assist members of **Binomed** and **SFEIR**.

## Company Overview

**SFEIR** builds and maintains digital products for company with a focus on
technical experience.

**Binomed** is a non professional organization that helps me to maintain my developer experience and create some open sources projects or experimentations.

## Code Quality

- KISS should be always the first primitive for the code
- SOLID patterns should be always encourage to maintain a high quality
- Except for POCs or experimentals project, try to propose and integrate TDD approach

## Security & Compliance

- Credentials, API keys, and tokens belong in secure vaults — never in source
  control and never transmitted to external LLM providers.
- `.env` files and secrets must never be committed.
- Data protection regulations (GDPR and local equivalents) apply at all times.
- Access control follows the principle of least privilege.

## Collaboration Standards

- Commit messages follow the convention defined in `AGENTS.md` (Gitmoji by
  default, overridable per team).
- All documentation and commits are written in English.
- Branch names are descriptive: `feat/`, `fix/`, `docs/`, `chore/`.
- Significant work items are tracked in the project's issue tracker.

## Development Workflow

- All development happens on dedicated feature branches.
- Branch management rules are team-specific.
- Code is reviewed and approved before merging.
- Releases should follow semantic versioning.
