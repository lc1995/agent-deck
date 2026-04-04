# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## Project Overview

**Agent Deck** — Terminal session manager for AI coding agents (Claude Code, Gemini CLI, Codex, OpenCode, etc.). Built with **Go 1.24** + **Bubble Tea** (TUI framework), runs on top of **tmux** as its core session management layer.

## Development Commands

```bash
make build        # Build binary to ./build/agent-deck (with version ldflags)
make run          # go run ./cmd/agent-deck
make dev          # Hot-reload dev server (uses `air`)
make test         # go test -race -v ./... (full suite, race detector on)
make fmt          # go fmt ./...
make lint         # golangci-lint run (auto-installs if missing)
make ci           # Full CI: lint + test + build in parallel (via lefthook pre-push)
make clean        # Remove build artifacts
```

### Run a Single Test

```bash
go test -race -v ./internal/session/...              # All tests in a package
go test -race -v ./internal/session -run TestFork    # Specific test by name
go test -race -v ./internal/tmux -run TestAttach     # Another example
go test -race -v ./internal/integration/...          # Integration/e2e tests
```

### Debug Mode

```bash
AGENTDECK_DEBUG=1 make run   # Enable debug logging
```

## Architecture

### Layer Structure

```
cmd/agent-deck/          CLI entry point & cobra-style subcommands (main.go is the TUI bootstrap)
  ├── internal/ui/       Bubble Tea TUI components (home.go = main view controller, ~371KB)
  ├── internal/session/  Core domain model: Instance, Group, Conductor, MCP catalog
  ├── internal/tmux/     tmux integration layer (session/window/pane management, status detection)
  ├── internal/statedb/  SQLite persistence (modernc.org/sqlite, pure Go)
  ├── internal/mcppool/  MCP Unix socket connection pool (shares MCP processes across sessions)
  ├── internal/web/      HTTP/WebSocket server (browser access, Web Push notifications)
  ├── internal/docker/   Docker sandbox for isolated agent execution
  └── internal/costs/    Cost tracking & budget system
```

### Key Large Files (Core Complexity)

| File | Size | Role |
|------|------|------|
| `internal/ui/home.go` | ~371KB | Main TUI view controller — all dashboard rendering & keyboard routing |
| `internal/tmux/tmux.go` | ~135KB | Core tmux operations — attach, send keys, capture output, state detection |
| `internal/session/instance.go` | ~174KB | Session instance lifecycle — create, fork, start, stop, migrate |
| `cmd/agent-deck/main.go` | ~92KB | CLI entry, command registration, TUI bootstrap |
| `internal/session/conductor.go` + `conductor_templates.go` | ~156KB+91KB | Conductor (persistent AI agent monitor) logic + prompt templates |

### Cross-Platform Code

Platform-specific files use Go build tags / filename conventions:
- `internal/docker/sandbox_darwin.go` vs `sandbox_other.go` — macOS vs other platforms for Docker sandbox
- Similar patterns exist throughout for platform differences

### Conductor System (Two-Part Architecture)

- **Go side**: `conductor_cmd.go` + `internal/session/conductor.go` — creates/manages persistent AI agent monitoring sessions
- **Python side**: `conductor/bridge.py` — Telegram/Slack bridge daemon (independent process)
- **Templates**: `conductor_templates.go` — generates CLAUDE.md/AGENTS.md identity files per conductor

### External Dependencies (Runtime)

- **tmux** — required; all session management is built on tmux sessions/windows/panes
- **Docker** (optional) — for sandbox/isolated execution mode
- **AI Agent CLIs** — Claude Code, Gemini CLI, Codex, OpenCode, etc. (the tools being managed)

## Git Hooks (Lefthook)

Configured in `lefthook.yml`:
- **pre-push** (parallel): lint (`golangci-lint`) + test (`go test -race`) + build (`go build`)
- **pre-commit** (parallel): fmt-check (`gofmt`) + vet (`go vet`)

These run automatically. Use `lefthook install` after clone if hooks aren't active.

## Configuration

- User config: `~/.agent-deck/config.toml` (TOML format, parsed via BurntSushi/toml)
- Key config options: MCP servers, cost budgets, pool settings (`pool_all = true` for socket pooling)

## Testing

- Unit tests: co-located `_test.go` files alongside source; uses `testify` for assertions
- Integration tests: `internal/integration/` — end-to-end tests with fixtures/harness
- E2E tests: `tests/e2e/` — uses Bun runtime + repterm (terminal automation)
- Always use `-race` flag for race detection

## Release Process

1. Update `Version` constant in `cmd/agent-deck/main.go`
2. Tag: `git tag v0.X.Y && git push --tags`
3. GitHub Actions `release.yml` auto-triggers: GoReleaser cross-compiles (linux/darwin × amd64/arm64), creates GitHub Release + Homebrew tap update
