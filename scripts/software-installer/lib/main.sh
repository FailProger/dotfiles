# Global consts
readonly LIB_DIR="$SCRIPT_DIR/lib"

# Modules declare their tools in __get_build_dependencies. Helpers must not
# install packages on their own, otherwise those packages escape the
# build/runtime accounting and cleanup.
lib__require_command() {
  local command_name="${1:?'Dont get command name!'}"
  local package_name="${2:-$1}"

  if command -v "$command_name" > /dev/null 2>&1; then
    return 0
  fi

  lib__log_error "Required command '$command_name' is missing; declare '$package_name' in __get_build_dependencies."
  return 1
}

# Imports
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/apt.sh"
source "$LIB_DIR/downloading.sh"
source "$LIB_DIR/file.sh"
source "$LIB_DIR/installation.sh"
source "$LIB_DIR/log.sh"
source "$LIB_DIR/root.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/manifest.sh"
