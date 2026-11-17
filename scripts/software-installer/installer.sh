#!/usr/bin/env bash

set -euo pipefail

# Global consts
readonly SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_usage() {
  cat << EOF
Usage: ./$(basename "$0") [OPTIONS] TARGET...

TARGETS:
  MODULE                Install a single module.
  CATEGORY              Install every module in a category under a group.
  GROUP                 Install every module in a group (a directory directly
                        under modules/software, e.g. user-software).
  all                   Install every module.

OPTIONS:
  -h, --help            Show this help and exit.
  -y, --yes             Skip the confirmation prompt.
  -n, --dry-run         Show the installation plan without changing anything.
  -l, --list            List all available modules and exit.
  -v, --verbose         Show the full install/configure matrix and all packages.
      --color WHEN      Color output: auto, always or never (default: auto).
      --install-only    Install apt dependencies and run __install only.
      --configure-only  Run __configure only.
  -f, --force           Re-run selected phases, ignoring saved state.
  -r, --reset           Remove saved state for the selected modules and exit.
  -m, --mark-installed  Mark selected modules as installed and exit.
      --keep-going      Continue with the remaining modules after a failure.

EXAMPLES:
  ./installer.sh -l
  ./installer.sh -y zsh
  ./installer.sh -n all
  ./installer.sh -n user-software
  ./installer.sh -n --verbose all
  ./installer.sh --color=never -n all
  ./installer.sh -r zsh
  ./installer.sh -m git

NOTES:
  Software is installed for the user who runs the script.
  Root operations ask for sudo only when they are needed.
  Running the script as root installs software for root, not for the
  current desktop user; normally run it without sudo.
EOF
}

main() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        _usage
        exit 0
        ;;
      --)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    _usage
    exit 0
  fi

  source "$SCRIPT_DIR/modules/command.sh"
  command_main "$@"
}

main "$@"
