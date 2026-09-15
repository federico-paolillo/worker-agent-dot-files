#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.inc"
require_herdr
require_jq
require_workspace

(( $# == 1 || $# == 2 )) || die "usage: ${0##*/} <agent-name> [prompt]"

agent_name="$1"
[[ "$agent_name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || die "agent name must match [a-z][a-z0-9_-]{0,31}"

created="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "$agent_name" --no-focus)"
tab_id="$(printf '%s\n' "$created" | jq -er '.result.tab.tab_id')"
pane_id="$(printf '%s\n' "$created" | jq -er '.result.root_pane.pane_id')"

report_retained_tab() {
  jq -cn --arg agent "$agent_name" --arg tab_id "$tab_id" --arg pane_id "$pane_id" \
    '{error:"agent setup failed; tab retained", agent:$agent, tab_id:$tab_id, pane_id:$pane_id}' >&2
}

if ! herdr agent start "$agent_name" --kind codex --pane "$pane_id" >/dev/null; then
  report_retained_tab
  exit 1
fi

if (( $# == 2 )) && ! herdr agent prompt "$agent_name" "$2" >/dev/null; then
  report_retained_tab
  exit 1
fi

jq -cn --arg agent "$agent_name" --arg tab_id "$tab_id" --arg pane_id "$pane_id" \
  '{agent:$agent, tab_id:$tab_id, pane_id:$pane_id}'
