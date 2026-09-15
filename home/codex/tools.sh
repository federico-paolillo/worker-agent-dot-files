#!/usr/bin/env bash

set -euo pipefail

install_dir="$HOME/.local/bin"

mkdir -p "$install_dir"

export PATH="$install_dir:$PATH"

curl -fsSL https://mise.run | MISE_INSTALL_PATH="$install_dir/mise" sh
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_INSTALL_DIR="$install_dir" CODEX_NON_INTERACTIVE=1 sh
curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$install_dir" sh

test -x "$install_dir/mise"
test -x "$install_dir/codex"
test -x "$install_dir/herdr"
