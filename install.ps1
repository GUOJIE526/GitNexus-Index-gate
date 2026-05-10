[CmdletBinding()]
param(
    [string[]]$Targets = @("codex"),
    [ValidateSet("user", "project")]
    [string]$Scope = "user",
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SkillName = "gitnexus-index-gate"
$RepoRoot = $PSScriptRoot
$SourceSkill = Join-Path $RepoRoot ".codex\skills\$SkillName"

function Get-HomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    return [Environment]::GetFolderPath("UserProfile")
}

function Expand-Targets {
    param(
        [string[]]$RawTargets,
        [string]$InstallScope
    )

    $items = @()
    foreach ($target in $RawTargets) {
        $items += ($target -split ",")
    }

    $items = $items |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($items -contains "all") {
        if ($InstallScope -eq "user") {
            return @("codex", "claude", "copilot", "opencode")
        }

        return @("codex", "claude", "copilot", "cursor", "opencode")
    }

    $valid = @("codex", "claude", "copilot", "cursor", "opencode")
    foreach ($item in $items) {
        if ($valid -notcontains $item) {
            throw "Unsupported target '$item'. Valid targets: $($valid -join ', '), all."
        }
    }

    return @($items | Select-Object -Unique)
}

function Copy-SkillFolder {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Overwrite
    )

    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd("\", "/")
    $destinationFull = [System.IO.Path]::GetFullPath($Destination).TrimEnd("\", "/")
    if ([string]::Equals($sourceFull, $destinationFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to install over the canonical source skill: $Source"
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    if (Test-Path -LiteralPath $Destination) {
        if (-not $Overwrite) {
            throw "Target already exists: $Destination. Re-run with -Force to replace it."
        }

        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
    Write-Host "Installed skill: $Destination"
}

function Write-CursorRule {
    param(
        [string]$Destination,
        [switch]$Overwrite
    )

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if (-not $Overwrite) {
            throw "Cursor rule already exists: $Destination. Re-run with -Force to replace it."
        }
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $content = @'
---
description: Check and refresh GitNexus indexes before graph-aware code work.
globs: "**/*"
alwaysApply: false
---

# GitNexus Index Gate

Use this rule before calling GitNexus MCP tools, GitNexus CLI commands, code graph search, impact analysis, route mapping, refactoring helpers, or architecture-aware implementation.

GitNexus indexes a specific git commit. After a new commit, pull, merge, rebase, or branch switch, the graph can be stale. Before using GitNexus MCP or CLI-backed intelligence, check `npx gitnexus status`. Continue only when the index is current and the indexed/current commits match. If the index is stale, missing, corrupt, or mismatched, run `npx gitnexus analyze`, then verify with `npx gitnexus status` again.

For repos that also use OpenSpec, inspect `openspec/` after the GitNexus gate passes. Use the active OpenSpec proposal, design, requirements, and tasks as the change contract. Use GitNexus query/context/impact data to locate affected modules and consumers before editing. After editing, run relevant tests and update OpenSpec verification/task notes.

If `.codex/skills/gitnexus-index-gate/scripts/ensure-gitnexus-index.ps1` or an installed copy is available, prefer it for the GitNexus freshness check.
'@

    Set-Content -LiteralPath $Destination -Value $content -Encoding utf8
    Write-Host "Installed Cursor rule: $Destination"
}

if (-not (Test-Path -LiteralPath (Join-Path $SourceSkill "SKILL.md") -PathType Leaf)) {
    throw "Canonical skill not found at $SourceSkill"
}

$expandedTargets = Expand-Targets -RawTargets $Targets -InstallScope $Scope
$homeDir = Get-HomeDirectory
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path

foreach ($target in $expandedTargets) {
    switch ($target) {
        "codex" {
            $destination = if ($Scope -eq "user") {
                Join-Path $homeDir ".codex\skills\$SkillName"
            } else {
                Join-Path $projectRoot ".codex\skills\$SkillName"
            }
            Copy-SkillFolder -Source $SourceSkill -Destination $destination -Overwrite:$Force
        }
        "claude" {
            $destination = if ($Scope -eq "user") {
                Join-Path $homeDir ".claude\skills\$SkillName"
            } else {
                Join-Path $projectRoot ".claude\skills\$SkillName"
            }
            Copy-SkillFolder -Source $SourceSkill -Destination $destination -Overwrite:$Force
        }
        "copilot" {
            $destination = if ($Scope -eq "user") {
                Join-Path $homeDir ".copilot\skills\$SkillName"
            } else {
                Join-Path $projectRoot ".github\skills\$SkillName"
            }
            Copy-SkillFolder -Source $SourceSkill -Destination $destination -Overwrite:$Force
        }
        "opencode" {
            $destination = if ($Scope -eq "user") {
                Join-Path $homeDir ".config\opencode\skills\$SkillName"
            } else {
                Join-Path $projectRoot ".opencode\skills\$SkillName"
            }
            Copy-SkillFolder -Source $SourceSkill -Destination $destination -Overwrite:$Force
        }
        "cursor" {
            if ($Scope -ne "project") {
                throw "Cursor is installed as a project rule. Use -Scope project -ProjectPath <repo>."
            }

            $destination = Join-Path $projectRoot ".cursor\rules\$SkillName.mdc"
            Write-CursorRule -Destination $destination -Overwrite:$Force
        }
    }
}
