#!/usr/bin/env bash

set -euo pipefail

# Global consts
readonly SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  source "$SCRIPT_DIR/modules/command.sh"
  command_main "$@"
}

main "$@"
