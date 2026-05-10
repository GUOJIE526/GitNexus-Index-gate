---
name: gitnexus-index-gate
description: Always run before an agent calls GitNexus MCP or CLI intelligence. Check gitnexus status every time, automatically run gitnexus analyze when the index is stale or missing, verify status again, then continue with GitNexus or OpenSpec-backed work.
---

# GitNexus Index Gate

## When to Use

Use this skill every time immediately before an agent calls GitNexus MCP tools, GitNexus CLI commands, graph-aware search, impact analysis, route mapping, context lookup, refactoring helpers, or any workflow that depends on GitNexus' indexed repository state.

Primary purpose: GitNexus indexes a specific git commit, so agents must not trust the graph until `gitnexus status` confirms the index is current. Do not wait until the agent observes a git operation. New commits, pulls, merges, rebases, and branch switches are common reasons for stale indexes, but they are not required triggers. The trigger is any upcoming GitNexus MCP or CLI use.

If the repo also uses OpenSpec, run this GitNexus gate first, then use the fresh graph to ground OpenSpec proposal, design, task, implementation, and verification work.

## Required Preflight

Run the GitNexus gate immediately before every GitNexus MCP or CLI-backed code intelligence workflow.

1. From anywhere inside the target git repo, check freshness with:

   ```powershell
   npx gitnexus status
   ```

2. Treat the index as usable only when status reports current or up to date, and `Indexed commit` matches `Current commit`.
3. If status says `stale`, asks to re-run `gitnexus analyze`, exits nonzero, reports no index, or shows different indexed/current commits, rebuild automatically:

   ```powershell
   npx gitnexus analyze
   ```

4. Run `npx gitnexus status` again. Continue with the requested GitNexus workflow only after the final status is current.
5. If the final status is still stale, or MCP tools still warn about stale data after a successful analyze, tell the user that the GitNexus MCP server may need a restart/reload before its in-memory index catches up.

Only after this gate passes should the agent call GitNexus query/context/impact/route/shape tools. Do not skip the gate because a previous turn checked status; re-check when a new GitNexus call is about to happen.

## Helper Script

Prefer the bundled helper when available:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/gitnexus-index-gate/scripts/ensure-gitnexus-index.ps1
```

Use `pwsh` instead of `powershell` when the environment already uses PowerShell 7.

The script:

- normalizes execution to the git repository root;
- runs `npx gitnexus status`;
- rebuilds with `npx gitnexus analyze` only when needed;
- verifies freshness with a second status check;
- exits `0` only when the index is current.

Useful options:

```powershell
# Inspect what would happen without rebuilding.
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/gitnexus-index-gate/scripts/ensure-gitnexus-index.ps1 -DryRun

# Force a full analyze before continuing.
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/gitnexus-index-gate/scripts/ensure-gitnexus-index.ps1 -Force
```

## Status Rules

Rebuild when any of these are true:

- output contains `stale` or `re-run gitnexus analyze`;
- `Indexed commit` and `Current commit` differ;
- `npx gitnexus status` exits nonzero;
- the status output suggests the index is missing, absent, corrupt, or not initialized;
- the user explicitly asked for a rebuild.

Do not rebuild when status is current/up to date and commit fields agree.

## OpenSpec Coordination

For repos that also contain `openspec/`, use OpenSpec as the planning and verification record after the GitNexus freshness gate passes.

1. Inspect `openspec/` for current changes, specs, and local agent instructions.
2. Before writing code, use GitNexus query/context/impact tools to locate relevant modules, routes, consumers, and blast radius.
3. Make or update the OpenSpec change artifacts that the repo expects: proposal, design notes, requirements/scenarios, and tasks.
4. Keep implementation scoped to the approved OpenSpec tasks and the GitNexus impact findings.
5. After editing, rerun relevant tests and use GitNexus impact or route/shape checks again when shared symbols, routes, or data contracts changed.
6. Update OpenSpec tasks/verification notes so the final state records what was implemented and how it was validated.

Prefer this sequence for feature or refactor work:

```text
GitNexus status -> analyze if stale -> verified fresh graph -> OpenSpec intent -> impact-aware design -> scoped code edits -> tests/checks
```

For quick read-only questions, OpenSpec is optional; the GitNexus freshness gate is still required before graph queries.

## Reporting

Before continuing, report a concise gate result:

- whether status was checked;
- whether `analyze` ran;
- the final status;
- indexed/current commit values when visible.

For implementation work, also report which OpenSpec change/spec was used, or say that no OpenSpec project/change was present.

Then proceed with the original task, such as impact analysis, query, context, route mapping, OpenSpec proposal work, or implementation.
