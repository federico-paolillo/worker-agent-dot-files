#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

readonly REPO_ROOT

sudo install -d -o root -g root -m 0755 -- /etc
sudo install -d -o root -g root -m 0755 -- /etc/apt
sudo install -d -o root -g root -m 0755 -- /etc/apt/apt.conf.d
sudo install -d -o root -g root -m 0755 -- /etc/apparmor.d
sudo install -d -o root -g root -m 0755 -- /etc/ssh
sudo install -d -o root -g root -m 0755 -- /etc/ssh/sshd_config.d

sudo install -o root -g root -m 0644 -t /etc/apt/apt.conf.d -- "$REPO_ROOT/etc/apt/apt.conf.d/"*
sudo install -o root -g root -m 0644 -- "$REPO_ROOT/etc/apparmor.d/chrome-dev-builds" /etc/apparmor.d/chrome-dev-builds
sudo install -o root -g root -m 0644 -t /etc/ssh/sshd_config.d -- "$REPO_ROOT/etc/ssh/sshd_config.d/"*

sudo install -d -o codex -g codex -m 0755 -- /home/codex
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/clean-architecture
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/clean-architecture/references
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/go
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/herdr
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/herdr-coordinator
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/herdr-coordinator/scripts
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/playwright-cli
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.agents/skills/playwright-cli/references
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.codex
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.config
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.config/mise
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.local
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.local/bin
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.local/bin/uchromium
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.local/bin/uchromium/152
sudo install -d -o codex -g codex -m 0755 -- /home/codex/.playwright
sudo install -d -o codex -g codex -m 0700 -- /home/codex/.ssh

sudo install -o codex -g codex -m 0755 -- "$REPO_ROOT/home/codex/tools.sh" /home/codex/tools.sh
sudo install -o codex -g codex -m 0644 -- "$REPO_ROOT/home/codex/.agents/skills/clean-architecture/SKILL.md" /home/codex/.agents/skills/clean-architecture/SKILL.md
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/clean-architecture/references -- "$REPO_ROOT/home/codex/.agents/skills/clean-architecture/references/"*
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/go -- "$REPO_ROOT/home/codex/.agents/skills/go/"*
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/herdr -- "$REPO_ROOT/home/codex/.agents/skills/herdr/"*
sudo install -o codex -g codex -m 0644 -- "$REPO_ROOT/home/codex/.agents/skills/herdr-coordinator/SKILL.md" /home/codex/.agents/skills/herdr-coordinator/SKILL.md
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/herdr-coordinator/scripts -- "$REPO_ROOT/home/codex/.agents/skills/herdr-coordinator/scripts/common.inc"
sudo install -o codex -g codex -m 0755 -t /home/codex/.agents/skills/herdr-coordinator/scripts -- "$REPO_ROOT/home/codex/.agents/skills/herdr-coordinator/scripts/"*.sh
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/playwright-cli -- "$REPO_ROOT/home/codex/.agents/skills/playwright-cli/"*.md
sudo install -o codex -g codex -m 0644 -t /home/codex/.agents/skills/playwright-cli/references -- "$REPO_ROOT/home/codex/.agents/skills/playwright-cli/references/"*
sudo install -o codex -g codex -m 0644 -t /home/codex/.codex -- "$REPO_ROOT/home/codex/.codex/"*
sudo install -o codex -g codex -m 0644 -- "$REPO_ROOT/home/codex/.codexrc" /home/codex/.codexrc
sudo install -o codex -g codex -m 0644 -t /home/codex/.config/mise -- "$REPO_ROOT/home/codex/.config/mise/"*
sudo install -o codex -g codex -m 0644 -t /home/codex/.playwright -- "$REPO_ROOT/home/codex/.playwright/"*
sudo install -o codex -g codex -m 0600 -- "$REPO_ROOT/home/codex/.ssh/authorized_keys" /home/codex/.ssh/authorized_keys
sudo install -o codex -g codex -m 0644 -t /home/codex/.local/bin/uchromium/152 -- "$REPO_ROOT/home/codex/.local/bin/uchromium/152/"*
