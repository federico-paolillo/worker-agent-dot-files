#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.inc"
require_herdr
require_jq

(( $# == 1 || $# == 2 )) || die "usage: ${0##*/} <tab-id> [lines]"
lines="${2:-120}"
[[ "$lines" =~ ^[1-9][0-9]*$ ]] || die "lines must be a positive integer"

agent="$(agent_for_tab "$1")"
herdr agent read "$agent" --source recent-unwrapped --lines "$lines"
