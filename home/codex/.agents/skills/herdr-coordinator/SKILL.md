---
name: herdr-coordinator
description: "Coordinate Codex agents in separate Herdr tabs with bundled scripts for spawning, listing, prompting, reading, sending keys, and closing tabs. Use only when the user explicitly requests a Herdr-based agent team. Requires HERDR_ENV=1."
---

# Herdr Coordinator

Use these wrappers when one coordinator needs one Codex agent per Herdr tab.
They turn opaque tab IDs into stable agent targets, avoid dependence on UI
focus, and reject every operation outside a Herdr-managed terminal.

Read and follow `../herdr/SKILL.md` before using them. Resolve this skill's
directory, then invoke scripts from its `scripts/` directory.

## Scripts

```text
spawn-codex-tab.sh <agent-name> [prompt]
list-tabs.sh [workspace-id]
read-tab.sh <tab-id> [lines]
prompt-tab.sh <tab-id> <prompt> [agent-prompt-options...]
send-keys-tab.sh <tab-id> <key>...
close-tab.sh <tab-id>
```

- `spawn-codex-tab.sh` creates an unfocused tab in the current workspace at the
  current directory, starts a named Codex agent, optionally submits initial work
  without waiting, and prints `agent`, `tab_id`, and `pane_id` as JSON.
- `list-tabs.sh` prints Herdr's tab-list JSON for the current workspace unless
  another workspace ID is supplied.
- `read-tab.sh` reads the tab agent's unwrapped transcript; it defaults to 120
  lines.
- `prompt-tab.sh` submits input through the agent-aware surface. Add
  `--wait --timeout 120000` when the coordinator should wait for a settled
  state.
- `send-keys-tab.sh` sends logical keys such as `esc`, `enter`, `up`, or
  `ctrl+c` to the tab's agent UI.
- `close-tab.sh` closes the tab. Closing the last tab also closes its workspace.

Example:

```bash
skill_dir=/home/codex/.agents/skills/herdr-coordinator
created=$($skill_dir/scripts/spawn-codex-tab.sh reviewer "Review the current diff")
tab_id=$(printf '%s\n' "$created" | jq -r .tab_id)
$skill_dir/scripts/read-tab.sh "$tab_id"
$skill_dir/scripts/prompt-tab.sh "$tab_id" "Return only actionable findings" --wait --timeout 120000
```

These wrappers require exactly one recognized live agent in a targeted tab. If a
tab has zero or multiple agents, use the native Herdr agent commands with an
explicit name or pane ID.

If agent startup or initial prompting fails, the new tab is deliberately
retained and its IDs are reported on stderr: `agent_not_ready` can still leave a
live agent. Inspect it before retrying or closing it. Never use
`send-keys-tab.sh` to answer an approval or question without the user's
authorization.
