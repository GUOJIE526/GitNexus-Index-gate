#!/usr/bin/env bash
set -euo pipefail

skill_name="gitnexus-index-gate"
targets="codex"
scope="user"
project_path="$PWD"
force=0

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_skill="$script_dir/.codex/skills/$skill_name"

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh --targets codex,claude,copilot,opencode --scope user --force
  ./install.sh --targets codex,claude,copilot,cursor --scope project --project-path /path/to/repo --force

Targets: codex, claude, copilot, cursor, opencode, all
Scopes: user, project
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets)
      targets="${2:-}"
      shift 2
      ;;
    --scope)
      scope="${2:-}"
      shift 2
      ;;
    --project-path)
      project_path="${2:-}"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$scope" != "user" && "$scope" != "project" ]]; then
  echo "Unsupported scope: $scope" >&2
  exit 2
fi

if [[ "$scope" == "project" && -z "${project_path// }" ]]; then
  echo "--project-path cannot be empty when --scope project is used." >&2
  exit 2
fi

if [[ ! -f "$source_skill/SKILL.md" ]]; then
  echo "Canonical skill not found at $source_skill" >&2
  exit 1
fi

project_root="$(cd "$project_path" && pwd)"

copy_skill() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"

  local source_real
  local dest_real
  source_real="$(cd "$source_skill" && pwd)"
  dest_real="$(cd "$(dirname "$dest")" && pwd)/$(basename "$dest")"
  if [[ "$source_real" == "$dest_real" ]]; then
    echo "Refusing to install over the canonical source skill: $source_skill" >&2
    exit 1
  fi

  if [[ -e "$dest" ]]; then
    if [[ "$force" != "1" ]]; then
      echo "Target already exists: $dest. Re-run with --force to replace it." >&2
      exit 1
    fi
    rm -rf "$dest"
  fi

  cp -R "$source_skill" "$dest"
  echo "Installed skill: $dest"
}

write_cursor_rule() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" && "$force" != "1" ]]; then
    echo "Cursor rule already exists: $dest. Re-run with --force to replace it." >&2
    exit 1
  fi

  cat > "$dest" <<'RULE'
---
description: Check and refresh GitNexus indexes before every GitNexus use.
globs: "**/*"
alwaysApply: false
---

# GitNexus Index Gate

Use this rule every time before calling GitNexus MCP tools, GitNexus CLI commands, code graph search, impact analysis, route mapping, refactoring helpers, or architecture-aware implementation.

GitNexus indexes a specific git commit. Do not wait until a git operation is observed; new commits, pulls, merges, rebases, and branch switches are common stale-index causes, but the trigger is any upcoming GitNexus MCP or CLI use. Before using GitNexus MCP or CLI-backed intelligence, check `npx gitnexus status`. Continue only when the index is current and the indexed/current commits match. If the index is stale, missing, corrupt, or mismatched, run `npx gitnexus analyze`, then verify with `npx gitnexus status` again.

For repos that also use OpenSpec, inspect `openspec/` after the GitNexus gate passes. Use the active OpenSpec proposal, design, requirements, and tasks as the change contract. Use GitNexus query/context/impact data to locate affected modules and consumers before editing. After editing, run relevant tests and update OpenSpec verification/task notes.

If `.codex/skills/gitnexus-index-gate/scripts/ensure-gitnexus-index.ps1` or an installed copy is available, prefer it for the GitNexus freshness check.
RULE

  echo "Installed Cursor rule: $dest"
}

IFS=',' read -r -a target_array <<< "$targets"
if [[ " ${target_array[*]} " == *" all "* ]]; then
  if [[ "$scope" == "user" ]]; then
    target_array=(codex claude copilot opencode)
  else
    target_array=(codex claude copilot cursor opencode)
  fi
fi

for target in "${target_array[@]}"; do
  target="$(echo "$target" | tr '[:upper:]' '[:lower:]' | xargs)"
  case "$target" in
    codex)
      if [[ "$scope" == "user" ]]; then
        copy_skill "$HOME/.codex/skills/$skill_name"
      else
        copy_skill "$project_root/.codex/skills/$skill_name"
      fi
      ;;
    claude)
      if [[ "$scope" == "user" ]]; then
        copy_skill "$HOME/.claude/skills/$skill_name"
      else
        copy_skill "$project_root/.claude/skills/$skill_name"
      fi
      ;;
    copilot)
      if [[ "$scope" == "user" ]]; then
        copy_skill "$HOME/.copilot/skills/$skill_name"
      else
        copy_skill "$project_root/.github/skills/$skill_name"
      fi
      ;;
    opencode)
      if [[ "$scope" == "user" ]]; then
        copy_skill "$HOME/.config/opencode/skills/$skill_name"
      else
        copy_skill "$project_root/.opencode/skills/$skill_name"
      fi
      ;;
    cursor)
      if [[ "$scope" != "project" ]]; then
        echo "Cursor is installed as a project rule. Use --scope project --project-path <repo>." >&2
        exit 1
      fi
      write_cursor_rule "$project_root/.cursor/rules/$skill_name.mdc"
      ;;
    "")
      ;;
    *)
      echo "Unsupported target: $target" >&2
      exit 2
      ;;
  esac
done
