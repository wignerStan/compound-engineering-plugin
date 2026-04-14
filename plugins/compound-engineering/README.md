# Compound Engineering (Stripped)

Stripped fork of [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) keeping only the research agents and knowledge management loop. All review personas, workflow utilities, and framework-specific skills have been removed.

## What's Kept

### Agents (8 research)

| Agent | Purpose |
|-------|---------|
| `learnings-researcher` | Search `docs/solutions/` for past institutional knowledge |
| `session-historian` | Search Claude Code/Codex/Cursor session history |
| `repo-research-analyst` | Analyze repo structure, patterns, and conventions |
| `issue-intelligence-analyst` | Fetch and analyze GitHub issues for themes/patterns |
| `slack-researcher` | Search Slack for organizational context |
| `best-practices-researcher` | Research industry best practices and patterns |
| `framework-docs-researcher` | Gather framework/library documentation |
| `git-history-analyzer` | Trace code evolution through git history |

### Skills (7 knowledge loop + research integrators)

| Skill | Description |
|-------|-------------|
| `/ce:compound` | Document solved problems to `docs/solutions/` (the knowledge base) |
| `/ce:compound-refresh` | Refresh stale learnings in `docs/solutions/` |
| `/ce-sessions` | Ask questions about session history |
| `/ce:plan` | Plan with learnings-researcher + repo-research-analyst dispatch |
| `/ce:ideate` | Ideate with learnings-researcher + issue-intelligence dispatch |
| `/ce:brainstorm` | Brainstorm with slack-researcher dispatch |
| `/ce-debug` | Debug with post-mortem documentation via `/ce:compound` |

## Knowledge Loop

The core value: `/ce:compound` writes solutions to `docs/solutions/`, and the research agents read from it. Over time, the plugin builds institutional memory about your codebase's solved problems, patterns, and decisions.

## Upstream Sync

This fork automatically tracks upstream via a manifest-based strip. See `scripts/strip-manifest.json` for the list of kept files. Run `scripts/sync-from-upstream.sh` to pull upstream changes.

## Removed

- 23 review agent personas (replaced by base-model prompting or superpowers plugin)
- 33 skills (planning, debugging, review, git workflow, framework-specific)
- All non-research agents
