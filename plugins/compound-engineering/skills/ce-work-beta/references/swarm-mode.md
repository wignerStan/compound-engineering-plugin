# Swarm Mode with Agent Teams

For genuinely large plans where agents need to communicate with each other, challenge approaches, or coordinate across 10+ tasks with persistent specialized roles, use agent team capabilities if available (e.g., Agent Teams in Claude Code).

**Agent teams are typically experimental and require opt-in.** Do not attempt to use agent teams unless the user explicitly requests swarm mode or agent teams, and the platform supports it.

## When to Use Agent Teams vs Subagents

| Agent Teams | Subagents (standard mode) |
|-------------|---------------------------|
| Agents need to discuss and challenge each other's approaches | Each task is independent -- only the result matters |
| Persistent specialized roles (e.g., dedicated tester running continuously) | Workers report back and finish |
| 10+ tasks with complex cross-cutting coordination | 3-8 tasks with clear dependency chains |
| User explicitly requests "swarm mode" or "agent teams" | Default for most plans |

Most plans should use subagent dispatch from standard mode. Agent teams add significant token cost and coordination overhead -- use them when the inter-agent communication genuinely improves the outcome.

## Agent Teams Workflow

1. **Create team** -- use your available team creation mechanism
2. **Create task list** -- parse Implementation Units into tasks with dependency relationships
3. **Spawn teammates** -- assign specialized roles (implementer, tester, reviewer) based on the plan's needs. Give each teammate the plan file path and their specific task assignments
4. **Coordinate** -- the lead monitors task completion, reassigns work if someone gets stuck, and spawns additional workers as phases unblock
5. **Cleanup** -- shut down all teammates, then clean up the team resources
