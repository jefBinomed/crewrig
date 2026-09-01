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
- Communication: chat-first (WhatsApp, Telegram, Google Chat), asynchronous
  written communication preferred.

## MCP Server Declarations

No additional MCP servers beyond the framework defaults.

## Workflow Preferences

No additional workflow preferences beyond what is described in `AGENTS.md`
and `config/ORGANIZATION.md`.
