# Tools and MCP Server Guidelines

<!-- Framework-wide instructions (three-tier memory architecture, MemPalace
     protocol, harness engineering loop, Sequential Thinking, Obsidian access
     model) are in the core rules file deployed at priority 60. This file,
     deployed at priority 65, carries organization-specific additions only. -->

Prefer integrated MCP tools over ad-hoc alternatives unless the user
explicitly directs otherwise.

## Tooling Preferences

- Editor: VS Code or Antigravity, with git plugins and a frontend-oriented
  setup (Prettier, ESLint).
- Terminal: zsh.
- Cloud: GCP environment (Cloud Run, Firebase Hosting, Datastore).
- CI/CD: GitHub Actions, self-hosted runners, Docker.
- Forge: GitHub through the `gh` CLI.
- Communication: chat-first (WhatsApp, Telegram, Google Chat), asynchronous
  written communication preferred.

## MCP Server Declarations

Declared once in `mcp-servers.org.json` and delivered to every CLI:

- `playwright` — drive a real browser for end-to-end checks and user-journey
  verification.
- `chrome-devtools` — inspect a running page: console, network, performance
  traces, Lighthouse, accessibility.
- `StitchMCP` — Google Stitch UI design generation. Requires `STITCH_API_KEY`
  in the environment.

## Agent Tooling

These tools are installed and managed outside CrewRig; use them when present.

- `tessl` — spec-driven development, configured per project through
  `.tessl/RULES.md`. When a repository carries it, tessl owns that project's
  spec workflow.
- `plannotator` — rich browser review of plans and documents; the configured
  user-gate validation backend.
- `rtk` — token-optimized CLI proxy (Claude Code hook); commands are
  rewritten transparently.
- `graphify` — turns any input (code, docs, papers, media) into a persistent
  knowledge graph (`/graphify`). When a repository contains `graphify-out/`,
  answer codebase and architecture questions with a graphify query first
  (`graphify query`, `graphify path`, `graphify explain`). The skill is owned
  by graphify's own installer (`graphify install`), not by CrewRig.

## Workflow Preferences

No additional workflow preferences beyond what is described in `AGENTS.md`
and `config/ORGANIZATION.md`.
