#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.inc"
require_herdr
require_jq

(( $# >= 2 )) || die "usage: ${0##*/} <tab-id> <key>..."
tab_id="$1"
shift

agent="$(agent_for_tab "$tab_id")"
herdr agent send-keys "$agent" "$@"
