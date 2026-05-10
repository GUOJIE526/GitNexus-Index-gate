param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Command
    )

    $exe = $Command[0]
    $args = @()
    if ($Command.Count -gt 1) {
        $args = $Command[1..($Command.Count - 1)]
    }

    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            $output = & $exe @args 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        return [pscustomobject]@{
            ExitCode = [int]$exitCode
            Output = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
    catch {
        return [pscustomobject]@{
            ExitCode = 127
            Output = $_.Exception.Message
        }
    }
}

function Get-StatusField {
    param(
        [string]$Text,
        [string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    foreach ($line in ($Text -split "\r?\n")) {
        if ($line -match "^\s*$escapedName\s*:\s*(.+?)\s*$") {
            return $Matches[1].Trim()
        }
    }

    return $null
}

function Normalize-Commit {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $match = [regex]::Match($Value, "[0-9a-fA-F]{7,40}")
    if (-not $match.Success) {
        return $null
    }

    return $match.Value.ToLowerInvariant()
}

function Test-SameCommit {
    param(
        [string]$Left,
        [string]$Right
    )

    $leftCommit = Normalize-Commit $Left
    $rightCommit = Normalize-Commit $Right

    if (-not $leftCommit -or -not $rightCommit) {
        return $true
    }

    return $leftCommit.StartsWith($rightCommit) -or $rightCommit.StartsWith($leftCommit)
}

function Get-GitNexusStatusState {
    param(
        [int]$ExitCode,
        [string]$Output,
        [bool]$ForceRefresh
    )

    $status = Get-StatusField $Output "Status"
    $indexedCommit = Get-StatusField $Output "Indexed commit"
    $currentCommit = Get-StatusField $Output "Current commit"
    $lower = $Output.ToLowerInvariant()

    $needsAnalyze = $ForceRefresh

    if ($ExitCode -ne 0) {
        $needsAnalyze = $true
    }

    $staleMarkers = @(
        "stale",
        "re-run gitnexus analyze",
        "rerun gitnexus analyze",
        "not indexed",
        "no index",
        "missing",
        "corrupt",
        "not initialized"
    )

    foreach ($marker in $staleMarkers) {
        if ($lower.Contains($marker)) {
            $needsAnalyze = $true
            break
        }
    }

    if (-not (Test-SameCommit $indexedCommit $currentCommit)) {
        $needsAnalyze = $true
    }

    return [pscustomobject]@{
        NeedsAnalyze = [bool]$needsAnalyze
        Status = $status
        IndexedCommit = $indexedCommit
        CurrentCommit = $currentCommit
    }
}

$root = Invoke-CapturedCommand @("git", "rev-parse", "--show-toplevel")
if ($root.ExitCode -ne 0) {
    Write-Error "GitNexus index gate must run inside a git repository. $($root.Output)"
    exit 1
}

$repoRoot = ($root.Output -split "\r?\n" | Select-Object -First 1).Trim()
Set-Location $repoRoot

Write-Host "[gitnexus-index-gate] Repository: $repoRoot"
Write-Host "[gitnexus-index-gate] Checking: npx gitnexus status"

$initialStatus = Invoke-CapturedCommand @("npx", "gitnexus", "status")
if (-not [string]::IsNullOrWhiteSpace($initialStatus.Output)) {
    Write-Host $initialStatus.Output
}

$initialState = Get-GitNexusStatusState `
    -ExitCode $initialStatus.ExitCode `
    -Output $initialStatus.Output `
    -ForceRefresh ([bool]$Force)

if (-not $initialState.NeedsAnalyze) {
    Write-Host "[gitnexus-index-gate] Index is current. Continuing."
    exit 0
}

if ($DryRun) {
    Write-Warning "[gitnexus-index-gate] Index needs rebuild, but -DryRun was set."
    exit 2
}

Write-Host "[gitnexus-index-gate] Rebuilding: npx gitnexus analyze"
$analyze = Invoke-CapturedCommand @("npx", "gitnexus", "analyze")
if (-not [string]::IsNullOrWhiteSpace($analyze.Output)) {
    Write-Host $analyze.Output
}

if ($analyze.ExitCode -ne 0) {
    Write-Error "[gitnexus-index-gate] gitnexus analyze failed with exit code $($analyze.ExitCode)."
    exit $analyze.ExitCode
}

if ($SkipVerify) {
    Write-Host "[gitnexus-index-gate] Analyze completed; verification skipped."
    exit 0
}

Write-Host "[gitnexus-index-gate] Verifying: npx gitnexus status"
$finalStatus = Invoke-CapturedCommand @("npx", "gitnexus", "status")
if (-not [string]::IsNullOrWhiteSpace($finalStatus.Output)) {
    Write-Host $finalStatus.Output
}

$finalState = Get-GitNexusStatusState `
    -ExitCode $finalStatus.ExitCode `
    -Output $finalStatus.Output `
    -ForceRefresh $false

if ($finalStatus.ExitCode -eq 0 -and -not $finalState.NeedsAnalyze) {
    Write-Host "[gitnexus-index-gate] Index is current after verification. Continuing."
    exit 0
}

Write-Error "[gitnexus-index-gate] Index still appears stale after analyze. Restart or reload the GitNexus MCP server if MCP tools keep reporting stale data."
exit 3
