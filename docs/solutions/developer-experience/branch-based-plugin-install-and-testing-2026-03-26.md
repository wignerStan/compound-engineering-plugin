---
title: "Branch-based plugin install and testing for Claude Code plugins"
date: 2026-03-26
problem_type: developer_experience
category: developer-experience
component: development_workflow
root_cause: missing_workflow_step
resolution_type: workflow_improvement
severity: medium
tags:
  - cli
  - plugin-install
  - branch-testing
  - developer-experience
  - git-clone
  - plugin-path
symptoms:
  - "No way to install or test a Claude Code plugin from a specific git branch"
  - "install command always cloned the default branch from GitHub"
  - "claude --plugin-dir only accepts a local filesystem path with no branch support"
  - "Developers had to manually checkout branches to test others' plugin changes"
root_cause_detail: "The CLI lacked any mechanism to target a specific git branch when installing or testing plugins. Claude Code's --plugin-dir flag only accepts local paths, and the install command had no --branch option."
solution_summary: "Added a new plugin-path subcommand that clones a specific branch to a deterministic cache path (~/.cache/compound-engineering/branches/) and outputs it for use with claude --plugin-dir. Also added a --branch flag to the install command for non-Claude targets."
key_insight: "Worktree-based development means multiple branches are active simultaneously and the repo root checkout can't serve as a reliable plugin source. A deterministic cache path based on the sanitized branch name enables branch-specific plugin testing without disrupting any checkout, and re-runs update in place via git fetch + reset --hard."
files_changed:
  - src/commands/plugin-path.ts
  - src/commands/install.ts
  - src/index.ts
  - tests/plugin-path.test.ts
  - tests/cli.test.ts
verification_steps:
  - "Run bun test to confirm all tests pass including 5 new plugin-path tests and 1 new CLI test"
  - "Test plugin-path subcommand outputs correct deterministic cache path for a given branch"
  - "Test install --branch flag clones from the specified branch for non-Claude targets"
  - "Verify re-running plugin-path on same branch updates via fetch+reset rather than re-cloning"
related_docs:
  - docs/solutions/adding-converter-target-providers.md
  - docs/solutions/plugin-versioning-requirements.md
---

## Problem

The compound-engineering plugin CLI's `install` command always cloned the default branch from GitHub, and Claude Code's `--plugin-dir` flag only accepts local filesystem paths. Developers who wanted to test a plugin from a specific git branch had to manually check out that branch in their local repo, disrupting their working tree.

This is especially painful in worktree-based workflows. When a developer has multiple branches checked out as worktrees (e.g., one for a new skill, another for a bug fix), the main repo checkout is on a different branch than the worktrees. Running `install ./plugins/compound-engineering` from the repo root uses whichever branch the main checkout is on -- not the branch being developed in a worktree. There was no way to say "install the plugin as it exists on branch X" without navigating into the worktree directory or switching branches.

---

## Symptoms

- Running `bunx compound-engineering install <plugin>` always fetched the default branch regardless of what branch contained the changes under review.
- `claude --plugin-dir` required a local path, so there was no way to point it at a remote branch without a manual `git clone` or `git checkout`.
- Developers testing PR branches had to stash or commit their local work, switch branches, test, then switch back -- a disruptive and error-prone workflow.
- In worktree-based workflows, `./plugins/compound-engineering` in the repo root always points to the main checkout's branch, not the worktree branch being developed. Developers working on multiple branches simultaneously had no ergonomic way to install from a specific worktree's branch.
- No scripting path existed to spin up a branch-specific plugin directory for automated testing.

---

## What Didn't Work

- **Using `/tmp/` for cloned branches** was rejected because temporary directories are cleared on reboot, forcing a full re-clone every session and losing the fast-update path.
- **Random temp directory names** (e.g., `mktemp -d`) were rejected because they cause directory proliferation and make it impossible to re-run the same command and update in place.
- **Extending `claude --plugin-dir` itself** was not an option -- that flag is owned by Claude Code and only accepts local filesystem paths; the solution had to live in the plugin CLI layer.
- **Symlinking the bundled plugin** would not help because the bundled copy is always pinned to the installed CLI version, not an arbitrary remote branch.

---

## Solution

Two complementary features were added:

### 1. New `plugin-path` command (for Claude Code)

Clones a branch to a deterministic cache directory and prints the path for use with `claude --plugin-dir`.

```bash
bun run src/index.ts plugin-path compound-engineering --branch feat/new-agents
# Output: claude --plugin-dir ~/.cache/compound-engineering/branches/compound-engineering-feat-new-agents/plugins/compound-engineering
```

Key implementation details in `src/commands/plugin-path.ts`:

- Cache path: `~/.cache/compound-engineering/branches/<plugin>-<sanitized-branch>/`
- Branch sanitization: `branch.replace(/[^a-zA-Z0-9._-]/g, "-")`
- First run: `git clone --depth 1 --branch <name> <source> <dest>`
- Re-run: `git fetch origin <branch>` + `git reset --hard origin/<branch>`

### 2. `--branch` flag on `install` command (for Codex, OpenCode, etc.)

Threads a branch name through the full resolution chain so `install` clones from the specified branch instead of the default.

```bash
bun run src/index.ts install compound-engineering --to codex --branch feat/new-agents
```

Changes in `src/commands/install.ts`:

- When `--branch` is provided, skips bundled plugin lookup (user explicitly wants a remote version)
- Threaded through `resolvePluginPath` -> `resolveGitHubPluginPath` -> `cloneGitHubRepo`
- `cloneGitHubRepo` conditionally adds `--branch <name>` to `git clone --depth 1`

### Key difference between the two

`plugin-path` caches the checkout in `~/.cache/` for reuse across sessions. `install --branch` uses an ephemeral temp directory that's cleaned up after the install completes -- it only needs the clone long enough to read and convert the plugin.

---

## Why This Works

The root issue was a missing indirection layer: the CLI assumed "install" always means "use the default branch," and Claude Code assumes "plugin directory" always means "a path that already exists locally." The solution bridges that gap by:

- **Deterministic cache paths** mean the same branch always maps to the same directory. No proliferation, no ambiguity.
- **Fetch + hard reset on re-run** keeps the cached checkout current without requiring a full re-clone, making iteration fast.
- **`~/.cache/`** follows XDG conventions, persists across reboots, and is understood by users and tooling as a safe-to-delete cache layer.
- **The `COMPOUND_PLUGIN_GITHUB_SOURCE` env var** works with both features, allowing tests to use local git repos and avoiding network dependency.

---

## Prevention

- **Test coverage**: `tests/plugin-path.test.ts` (5 tests: clone-to-cache, slash sanitization, update-on-rerun, nonexistent branch error, nonexistent plugin error) and `tests/cli.test.ts` (1 test: install --branch clones specific branch). All tests use local git repos via `COMPOUND_PLUGIN_GITHUB_SOURCE`.
- **Cache directory convention**: Any future features that need ephemeral or semi-persistent clones should use `~/.cache/compound-engineering/<purpose>/` with deterministic, sanitized subdirectory names. Avoid `/tmp/` for anything that benefits from surviving a reboot.
- **Branch sanitization**: Always sanitize branch names before using them in filesystem paths. The `replace(/[^a-zA-Z0-9._-]/g, "-")` pattern prevents path traversal and special-character issues.
- **Resolution chain threading**: When adding new resolution strategies to the CLI, thread optional parameters through the full `resolvePluginPath -> resolveGitHubPluginPath -> cloneGitHubRepo` chain rather than branching at the top level. This keeps the resolution logic composable.
