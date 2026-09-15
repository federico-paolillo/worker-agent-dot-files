#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.inc"
require_herdr

(( $# <= 1 )) || die "usage: ${0##*/} [workspace-id]"
workspace_id="${1:-${HERDR_WORKSPACE_ID:-}}"
[[ -n "$workspace_id" ]] || die "workspace ID is required when HERDR_WORKSPACE_ID is not set"

herdr tab list --workspace "$workspace_id"
