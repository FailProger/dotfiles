# Root privileges. The installer itself runs as the target user; sudo is
# requested lazily, only when a command actually needs root.

lib__as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
    return
  fi

  if ! sudo -n true 2> /dev/null; then
    lib__require_sudo || return 1
  fi

  lib__start_sudo_keepalive
  sudo "$@"
}

# Make sure sudo credentials are available, asking for the password once.
lib__require_sudo() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi

  if ! command -v sudo > /dev/null 2>&1; then
    lib__log_error 'sudo is required but is not installed.'
    return 1
  fi

  if sudo -n true 2> /dev/null; then
    return 0
  fi

  lib__log_info 'Root privileges are required; requesting sudo.'
  if ! sudo -v; then
    lib__log_error 'Failed to get sudo privileges.'
    return 1
  fi
}

# Keep the sudo timestamp fresh during long installations.
lib__start_sudo_keepalive() {
  if [[ $EUID -eq 0 || -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    return 0
  fi

  # Never start the refresh loop from a phase subshell: it would outlive the
  # phase. The orchestrator starts one in the main process when credentials
  # are cached.
  if [[ "${BASHPID:-$$}" != "$$" ]]; then
    return 0
  fi

  (
    while true; do
      sudo -n true 2> /dev/null || exit 0
      sleep 60
    done
  ) &

  SUDO_KEEPALIVE_PID=$!
}

lib__stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
    wait "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
    SUDO_KEEPALIVE_PID=''
  fi
}
