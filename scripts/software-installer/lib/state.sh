# State layout:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/
#   ├── lock
#   └── modules/<group>__<category>__<module>/
#       ├── fingerprint
#       ├── install.done|failed|running
#       ├── configure.done|failed|running
#       ├── install.log
#       └── configure.log

STATE_ROOT=''
STATE_LOCK_FD=''
CURRENT_STATE_KEY=''
CURRENT_STATE_PHASE=''

lib__state_root() {
  printf '%s/software-installer\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

# Set the state root without creating anything. Used by --dry-run.
lib__state_load() {
  STATE_ROOT="$(lib__state_root)"
}

lib__state_init() {
  lib__state_load
  mkdir -p "$STATE_ROOT/modules"
  chmod 755 "$STATE_ROOT" "$STATE_ROOT/modules"
}

lib__state_module_dir() {
  local key="${1:?'Do not get module key!'}"

  printf '%s/modules/%s\n' "$STATE_ROOT" "$key"
}

# Atomically write a state file, creating its directory when needed.
lib__state_write() {
  local file="${1:?'Dont get file path!'}"
  shift
  local content="${*:-}"
  local dir
  local tmp

  dir="$(dirname "$file")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.tmp.XXXXXX")"
  printf '%s\n' "$content" > "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$file"
}

lib__state_fingerprint() {
  local file="${1:?'Dont get file path!'}"

  sha256sum "$file" | awk '{ print $1 }'
}

# Record the current module fingerprint. When the module file changes, old
# done markers stop matching and the phase runs again.
lib__state_module_init() {
  local key="${1:?'Dont get module key!'}"
  local file="${2:?'Dont get module file!'}"

  lib__state_write "$(lib__state_module_dir "$key")/fingerprint" \
    "$(lib__state_fingerprint "$file")"
}

lib__state_phase_done() {
  local key="${1:?'Dont get module key!'}"
  local phase="${2:?'Dont get phase!'}"
  local file="${3:?'Dont get module file!'}"
  local dir
  local stored
  local current

  dir="$(lib__state_module_dir "$key")"
  [[ -f "$dir/$phase.done" ]] || return 1

  # The done marker stores the module fingerprint at the time the phase
  # completed, so changing the module invalidates that exact phase.
  stored="$(head -n1 "$dir/$phase.done")"
  current="$(lib__state_fingerprint "$file")"

  [[ -n "$stored" && "$stored" == "$current" ]]
}

lib__state_reset() {
  local key="${1:?'Do not get module key!'}"

  rm -rf "$(lib__state_module_dir "$key")"
}

lib__state_lock() {
  local lock="$STATE_ROOT/lock"

  mkdir -p "$STATE_ROOT"
  touch "$lock"
  chmod 644 "$lock"

  # flock(2) allows an exclusive lock on a read-only descriptor, so the lock
  # works no matter who created the file.
  if ! exec {STATE_LOCK_FD}< "$lock"; then
    lib__log_error "Cannot open state lock: $lock"
    return 1
  fi

  if ! flock -n "$STATE_LOCK_FD"; then
    lib__log_error 'Another installer instance is already running.'
    exec {STATE_LOCK_FD}<&-
    STATE_LOCK_FD=''
    return 1
  fi
}

lib__state_unlock() {
  if [[ -n "${STATE_LOCK_FD:-}" ]]; then
    exec {STATE_LOCK_FD}<&-
    STATE_LOCK_FD=''
  fi
}

lib__state_interrupt() {
  local dir

  trap - INT TERM

  if [[ -n "${CURRENT_STATE_KEY:-}" && -n "${CURRENT_STATE_PHASE:-}" ]]; then
    dir="$(lib__state_module_dir "$CURRENT_STATE_KEY")"
    rm -f "$dir/$CURRENT_STATE_PHASE.running"
    lib__state_write "$dir/$CURRENT_STATE_PHASE.failed" 'interrupted'
  fi

  lib__log_warn 'Interrupted.'
  exit 130
}

# Run one module phase, capturing output to its log and recording the result.
lib__state_run_phase() {
  local key="${1:?'Dont get module key!'}"
  local phase="${2:?'Dont get phase!'}"
  local file="${3:?'Dont get module file!'}"
  shift 3

  local dir
  local log
  local rc

  dir="$(lib__state_module_dir "$key")"
  log="$dir/$phase.log"
  mkdir -p "$dir"
  touch "$log"
  chmod 600 "$log"

  rm -f "$dir/$phase.done" "$dir/$phase.failed"
  lib__state_write "$dir/$phase.running" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  CURRENT_STATE_KEY="$key"
  CURRENT_STATE_PHASE="$phase"
  trap 'lib__state_interrupt' INT TERM

  if "$@" 2>&1 | tee -a "$log"; then
    rc=0
  else
    rc=${PIPESTATUS[0]}
  fi

  trap - INT TERM
  CURRENT_STATE_KEY=''
  CURRENT_STATE_PHASE=''

  rm -f "$dir/$phase.running"

  if [[ $rc -eq 0 ]]; then
    lib__state_write "$dir/$phase.done" "$(lib__state_fingerprint "$file")"
  else
    lib__state_write "$dir/$phase.failed" "exit_code=$rc"
  fi

  return "$rc"
}
