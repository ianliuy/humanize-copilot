# Install Humanize for GitHub Copilot CLI

Humanize is shaped as a Claude Code plugin, but its hook contract is compatible with GitHub Copilot CLI's plugin-hook system. This guide describes how to install Humanize into Copilot CLI and what Windows users need.

## Prerequisites

- A working installation of [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli) at version **1.0.22 or later**. Earlier versions either lack the `CLAUDE_PLUGIN_ROOT` environment variable injection (added in 0.0.410) or do not honor the Claude Code-compatible nested matcher/hooks structure (added in 1.0.6) or do not emit VS Code-compatible snake_case payloads alongside PascalCase event names (added in 1.0.21). Verify with `copilot --version`.
- `git` and `jq` on `PATH` (same prerequisites as the Claude install).
- On **Windows**: Git for Windows (Git Bash). See the Windows section below.

## Why Copilot CLI Works With Humanize

Humanize ships a Claude Code-style `hooks/hooks.json` manifest that Copilot CLI consumes natively. Specifically, the following Copilot CLI capabilities are what make this integration work:

- **Plugin install dirs are scanned for hooks**. When you install a plugin via Copilot CLI, its `hooks/hooks.json` (and the bash logic it points at) is loaded as part of plugin activation. (changelog 0.0.422, 2026-03-05; reiterated 1.0.22, 2026-04-09)
- **`CLAUDE_PLUGIN_ROOT` is injected**. Copilot CLI sets `CLAUDE_PLUGIN_ROOT` (alongside `PLUGIN_ROOT` and `COPILOT_PLUGIN_ROOT`) so a plugin-relative `${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh` path resolves to the actual installed location. (changelog 0.0.410, 2026-02-14)
- **Claude Code's nested matcher/hooks structure is supported**. Hooks like `PreToolUse` with `matcher: "Bash"` work out of the box. (changelog 1.0.6, 2026-03-16)
- **PascalCase event names + snake_case payload fields**. Copilot CLI accepts the Claude-style PascalCase events (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`) and delivers payloads with the snake_case shape Humanize hooks already consume (`tool_name`, `tool_input`, `session_id`). (changelog 1.0.21, 2026-04-07)
- **Native `Stop` / `agentStop` / `subagentStop` events**. Humanize's RLCR loop relies on per-round Stop dispatch; Copilot CLI provides this directly, no trigger-bridge needed. (changelog 0.0.389, 2026-01-22)
- **OS-specific command overrides in hook entries**. Hook entries accept `command` (default), `windows`, `linux`, and `osx` fields. Humanize ships a `windows` override on every `hooks.json` entry pointing at a `.cmd` launcher so Windows hosts dispatch the launcher (which delegates to bash) while Unix hosts dispatch the `.sh` directly via `command`. (per VS Code Agent Hooks documentation that Copilot CLI shares)

## Install Steps

```bash
# In Copilot CLI:
/plugin marketplace add PolyArch/humanize
/plugin install humanize@PolyArch
```

If you want experimental features ahead of the stable `main` release, use the `dev` branch:

```bash
/plugin marketplace add PolyArch/humanize#dev
/plugin install humanize@PolyArch
```

After install, restart your Copilot CLI session (or run `/reload-plugins` if available) so the hook manifest is picked up. The Humanize commands then become available the same way they do in Claude Code.

## Windows

The `.cmd` launchers under `hooks/` and `scripts/` are thin wrappers that locate `bash` and re-exec the sibling `.sh` while preserving stdin, argv, and exit codes. They are needed because Windows has no native dispatch for the `.sh` file extension; without the `.cmd` launcher, Copilot CLI on Windows would attempt to dispatch the `.sh` directly and Windows would hand it to whatever editor is registered for the `.sh` file association (typically VS Code) instead of executing it.

The supported Windows bash runtime is **Git for Windows**. Install it from [git-scm.com/download/win](https://git-scm.com/download/win). The launcher probes for bash in this order:

1. The first `bash` returned by `where bash`.
2. `C:\Program Files\Git\bin\bash.exe` (default 64-bit Git for Windows install path).
3. `C:\Program Files (x86)\Git\bin\bash.exe` (default 32-bit fallback).

When none of those resolve, the launcher exits non-zero and prints exactly:

```
Humanize: bash not found. Install Git for Windows (https://git-scm.com/download/win) or see docs/install-for-claude.md#windows.
```

MSYS2 and WSL are not currently probed in the launcher logic. If you have them, put their `bash.exe` on `PATH` so the `where bash` probe finds it. PowerShell-only environments are not supported in v1.

## Verify Installation

Trigger a Humanize command (e.g. `/humanize:gen-plan` or `/humanize:start-rlcr-loop`). On a Windows host:

- The first bash invocation through a hook should silently succeed.
- If it fails with the missing-bash stderr message, install Git for Windows and retry.

You can also confirm the plugin install location was recognized:

```bash
ls ~/.copilot/installed-plugins/PolyArch/humanize/hooks/
```

You should see both `.sh` and `.cmd` files for each registered hook (`loop-bash-validator.sh` + `loop-bash-validator.cmd`, etc.).

## Coexistence With Claude Code

A repo can have both Claude Code (`/plugin install humanize@PolyArch`) and Copilot CLI installations of Humanize active simultaneously. Both load the same `hooks/hooks.json` and dispatch the same hook bodies; the only difference is which host happens to be invoking them. Hook state files under `.humanize/rlcr/` and `.humanize/pr-loop/` are shared between them, so an RLCR loop started from one host can be observed (and reviewed) from the other if both are pointed at the same project working directory.

## Other Install Guides

- [Install for Claude Code](install-for-claude.md)
- [Install for Codex](install-for-codex.md)
- [Install for Kimi](install-for-kimi.md)
