# GitNexus Index Gate Agent Skill

Portable agent skill for repositories that use GitNexus as a code knowledge graph. Its main job is to make agents check and refresh the GitNexus index automatically before they use GitNexus.

Why this exists: GitNexus indexes a specific git commit. When a project gets a new commit, pull, merge, rebase, or branch switch, the existing index can become stale until someone runs `gitnexus analyze` again. This skill turns that manual step into an agent preflight.

The canonical skill lives at:

```text
.codex/skills/gitnexus-index-gate/
```

It can be installed into agents that support `SKILL.md` folders, or converted into a Cursor project rule by the installer.

## What It Does

- Makes agents run `npx gitnexus status` before GitNexus MCP/CLI work.
- Detects stale, missing, corrupt, nonzero, or commit-mismatched index states.
- Automatically rebuilds stale or missing indexes with `npx gitnexus analyze`.
- Verifies `npx gitnexus status` again before the agent continues.
- Optionally guides agents to use OpenSpec artifacts after the GitNexus graph is fresh.
- Encourages GitNexus impact analysis before editing shared symbols, routes, or contracts.

## Requirements

- Git repository target project.
- Node.js and `npx`.
- GitNexus available through `npx gitnexus` or a global install.
- Optional: OpenSpec initialized in the target project with `openspec init`.

## Install with PowerShell

If you downloaded a zip release, extract it first, then run commands from the extracted folder.

Install as personal/user skills:

```powershell
.\install.ps1 -Targets codex,claude,copilot,opencode -Scope user -Force
```

Install into a specific project:

```powershell
.\install.ps1 -Targets codex,claude,copilot,cursor -Scope project -ProjectPath C:\path\to\repo -Force
```

## Install with Bash

```bash
./install.sh --targets codex,claude,copilot,opencode --scope user --force
./install.sh --targets codex,claude,copilot,cursor --scope project --project-path /path/to/repo --force
```

## Target Paths

| Agent | User install | Project install |
| --- | --- | --- |
| Codex | `~/.codex/skills/gitnexus-index-gate` | `.codex/skills/gitnexus-index-gate` |
| Claude Code | `~/.claude/skills/gitnexus-index-gate` | `.claude/skills/gitnexus-index-gate` |
| GitHub Copilot | `~/.copilot/skills/gitnexus-index-gate` | `.github/skills/gitnexus-index-gate` |
| Cursor | project rule only | `.cursor/rules/gitnexus-index-gate.mdc` |
| OpenCode | `~/.config/opencode/skills/gitnexus-index-gate` | `.opencode/skills/gitnexus-index-gate` |

## Manual Install

Copy `.codex/skills/gitnexus-index-gate` to the skill directory for the target agent. Keep the folder name `gitnexus-index-gate` and keep `scripts/ensure-gitnexus-index.ps1` with `SKILL.md`.

## Package for Sharing

To create a distributable zip from this folder:

```powershell
New-Item -ItemType Directory -Force -Path dist | Out-Null
Compress-Archive -Path README.md,install.ps1,install.sh,.codex -DestinationPath dist\gitnexus-index-gate-skill.zip -Force
```

## Upstream Tool References

- GitNexus: https://github.com/abhigyanpatwari/GitNexus
- OpenSpec: https://github.com/Fission-AI/OpenSpec
