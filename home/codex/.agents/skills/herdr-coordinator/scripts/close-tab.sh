#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.inc"
require_herdr

(( $# == 1 )) || die "usage: ${0##*/} <tab-id>"
herdr tab close "$1"
