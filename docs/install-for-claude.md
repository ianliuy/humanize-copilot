# Install Humanize for Claude Code

## Prerequisites

- [codex](https://github.com/openai/codex) -- OpenAI Codex CLI (for review). Verify with `codex --version`.
- `jq` -- JSON processor. Verify with `jq --version`.
- `git` -- Git version control. Verify with `git --version`.

## Option 1: Git Marketplace (Recommended)

Start Claude Code and run:

```bash
# Add the marketplace
/plugin marketplace add git@github.com:PolyArch/humanize.git

# Install the plugin
/plugin install humanize@PolyArch
```

## Option 2: Local Development

If you have the plugin cloned locally:

```bash
claude --plugin-dir /path/to/humanize
```

## Option 3: Try Experimental Features (dev branch)

The `dev` branch contains experimental features that are not yet released to `main`. To try them locally:

```bash
git clone https://github.com/PolyArch/humanize.git
cd humanize
git checkout dev
```

Then start Claude Code with the local plugin directory:

```bash
claude --plugin-dir /path/to/humanize
```

Note: The `dev` branch may contain unstable or incomplete features. For production use, stick with Option 1 (Git Marketplace) which tracks the stable `main` branch.

## Verify Installation

After installing, you should see Humanize commands available:

```
/humanize:start-rlcr-loop
/humanize:gen-plan
/humanize:refine-plan
/humanize:ask-codex
```

## Monitor Setup (Optional)

Add the monitoring helper to your shell for real-time progress tracking:

```bash
# Add to your .bashrc or .zshrc
source ~/.claude/plugins/cache/PolyArch/humanize/<LATEST.VERSION>/scripts/humanize.sh
```

Then use:

```bash
humanize monitor rlcr   # Monitor RLCR loop
humanize monitor pr     # Monitor PR loop
```

## Windows

Humanize hooks are bash scripts. To run them on Windows, you need a working `bash` interpreter on `PATH` or installed in a known location. The supported runtime is **Git for Windows** (`bash.exe` shipped as part of Git Bash).

The `.cmd` launchers under `hooks/` and `scripts/` probe for bash in this order:

1. The first `bash` returned by `where bash` (so any user-installed Git Bash on `PATH` wins).
2. `C:\Program Files\Git\bin\bash.exe` (the default 64-bit Git for Windows install path).
3. `C:\Program Files (x86)\Git\bin\bash.exe` (the default 32-bit fallback).

When none of those resolve, the launcher exits non-zero and prints exactly:

```
Humanize: bash not found. Install Git for Windows (https://git-scm.com/download/win) or see docs/install-for-claude.md#windows.
```

Install Git for Windows from [git-scm.com/download/win](https://git-scm.com/download/win) and rerun. MSYS2 and WSL are not currently probed (they require different launch semantics); if you have them, ensure their `bash.exe` is on `PATH` so the `where bash` probe finds it. PowerShell is not used by Humanize launchers in v1.

## Other Install Guides

- [Install for Codex](install-for-codex.md)
- [Install for Kimi](install-for-kimi.md)
- [Install for Copilot](install-for-copilot.md)

## Next Steps

See the [Usage Guide](usage.md) for detailed command reference and configuration options.
