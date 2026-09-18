# Ubuntu 26.04 VPS overlay

This repository installs an idempotent configuration overlay for an existing
Ubuntu 26.04 host. It does not provision users, packages, firewalls, Rootless
Docker, or Chromium. User tools are installed separately by
`/home/codex/tools.sh` after applying the overlay.

## Overlay

The configuration files and directories mirror their destinations from the
target filesystem root. For example, `etc/ssh/sshd_config.d/00-hardening.conf`
is installed as `/etc/ssh/sshd_config.d/00-hardening.conf`.

## Prerequisites

Create the `codex` user and install system packages manually. In particular:

```bash
sudo apt update
sudo apt install jq unattended-upgrades
sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
```

Stage the Ungoogled Chromium bundle at `~/.local/bin/uchromium/152` using the
URL and checksum in `home/codex/.local/bin/uchromium/152/version` before using
its Playwright configuration.

## Install

Run the installer from any directory:

```bash
/path/to/vps-hardening/install.sh
```

As the `codex` user, add this line to the existing `~/.bashrc`; the installer
does not manage that file:

```bash
[ -f "$HOME/.codexrc" ] && . "$HOME/.codexrc"
```

As the `codex` user, install Mise, Codex, and Herdr from the home directory
without `sudo`:

```bash
cd ~
./tools.sh
```

Start a new Bash shell, then install the configured tools with Mise:

```bash
mise install
mise current
```

## Python

Use `uv` to install and select Python versions for each project:

```bash
uv python install <version>
uv python pin <version>
```

## SSH activation

Before manually reloading SSH, ensure TCP/65022 is open in every host, provider,
and network firewall. Keep the current SSH port and session available until a
second session has connected successfully on port 65022.

Validate and reload only after the overlay is installed:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

## Chromium

Chromium requires the following dependencies. Install them using `apt`

- libatk1.0-0t64
- libatk-bridge2.0-0t64
- libcups2t64
- libasound2t64
- libgbm1
- libcairo2
- libpango-1.0-0
- libxcomposite1
- libxdamage1
- libxfixes3
- libxrandr2

Review how to configure a proper AppArmor profile for Chromium
[on the official website](https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md).

The installer copies the Chromium AppArmor profile but does not activate it.
Validate and reload AppArmor after installation:

```bash
sudo aa-load --dryrun /etc/apparmor.d/chrome-dev-builds
sudo service apparmor reload
```

The Chromium executable is under the `codex` user's writable home directory.
Code running as `codex` can replace that executable and obtain the profile's
user-namespace exception. Treat this profile as a compatibility exception, not
as a security boundary against the `codex` account.
