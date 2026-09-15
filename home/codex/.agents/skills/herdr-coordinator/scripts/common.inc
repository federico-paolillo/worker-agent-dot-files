die() {
  printf 'herdr-coordinator: %s\n' "$*" >&2
  exit 1
}

require_herdr() {
  [[ "${HERDR_ENV:-}" == 1 ]] || die "must run inside a Herdr-controlled terminal (HERDR_ENV=1)"
  command -v herdr >/dev/null 2>&1 || die "herdr is not available in PATH"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is not available in PATH"
}

require_workspace() {
  [[ -n "${HERDR_WORKSPACE_ID:-}" ]] || die "HERDR_WORKSPACE_ID is not set"
}

agent_for_tab() {
  local tab_id="$1"

  herdr agent list | jq -er --arg tab_id "$tab_id" '
    [.result.agents[]? | select(.tab_id == $tab_id)] as $agents
    | if ($agents | length) == 1 then
        ($agents[0].name // $agents[0].pane_id)
      elif ($agents | length) == 0 then
        error("no live agent found in tab " + $tab_id)
      else
        error("multiple live agents found in tab " + $tab_id)
      end
  '
}
