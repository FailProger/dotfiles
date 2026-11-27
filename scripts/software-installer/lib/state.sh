# State layout:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/
#   ├── lock
#   └── modules/<group>__<category>__<module>/
#       ├── fingerprint
#       ├── install.done|failed|running
#       ├── configure.done|failed|running
#       ├── remove.failed|running
#       ├── deconfigure.failed|running
#       ├── install.log / configure.log / remove.log / deconfigure.log
#       ├── manual
#       └── external

STATE_ROOT=''
STATE_LOCK_FD=''
CURRENT_STATE_KEY=''
CURRENT_STATE_PHASE=''
MODULE_STATE_DIR=''
MODULE_KEY=''
MODULE_NAME=''

CLEANUP_PENDING_PACKAGES=()
CLEANUP_PENDING_MODULES=()

lib__state_root() {
  printf '%s/software-installer\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

# Set the state root without creating anything. Used by --dry-run.
lib__state_load() {
  STATE_ROOT="$(lib__state_root)"
}

lib__state_init() {
  local dir

  lib__state_load
  mkdir -p "$STATE_ROOT/modules"
  chmod 755 "$STATE_ROOT" "$STATE_ROOT/modules"

  # Migration from the old manual/owned model. Existing installs become
  # manual so an orphan sweep cannot remove them by surprise. Only the first
  # run after the upgrade does this.
  if [[ ! -f "$STATE_ROOT/migration.v2" ]]; then
    for dir in "$STATE_ROOT"/modules/*; do
      [[ -d "$dir" ]] || continue
      if [[ -f "$dir/manual.mark" ]]; then
        : > "$dir/manual"
        rm -f "$dir/manual.mark"
      elif [[ -f "$dir/install.done" && ! -f "$dir/external" ]]; then
        : > "$dir/manual"
      fi
    done
    : > "$STATE_ROOT/migration.v2"
    chmod 644 "$STATE_ROOT/migration.v2"
  fi
}

lib__state_module_dir() {
  local key="${1:?'Do not get module key!'}"

  printf '%s/modules/%s\n' "$STATE_ROOT" "$key"
}

# Temporary directories live under the per-phase root, which the phase runner
# removes when the phase finishes, successfully or not. The root is a normal
# variable, so it survives the command substitution used by callers.
lib__tmpdir() {
  local dir

  if [[ -n "${LIB_PHASE_TMPROOT:-}" && -d "${LIB_PHASE_TMPROOT}" ]]; then
    dir="$(mktemp -d "$LIB_PHASE_TMPROOT/tmp.XXXXXX")" || return 1
  else
    dir="$(mktemp -d)" || return 1
  fi

  printf '%s\n' "$dir"
}

# A phase marker that ignores the fingerprint. Used for removal decisions:
# the module was installed at some point even if its file changed since then.
lib__state_phase_marked() {
  local key="${1:?'Do not get module key!'}"
  local phase="${2:?'Do not get phase!'}"

  [[ -f "$(lib__state_module_dir "$key")/$phase.done" ]]
}

lib__state_has_install() {
  local key="${1:?'Do not get module key!'}"

  lib__state_phase_marked "$key" install || lib__state_is_external "$key"
}

# manual: the module is explicitly wanted (apt manual). It is never removed
# by an automatic orphan sweep. Dependencies installed for another module do
# not get this marker.
lib__state_manual_file() {
  local key="${1:?'Do not get module key!'}"

  printf '%s/manual\n' "$(lib__state_module_dir "$key")"
}

lib__state_mark_manual() {
  local key="${1:?'Do not get module key!'}"
  local file

  file="$(lib__state_manual_file "$key")"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

lib__state_is_manual() {
  local key="${1:?'Do not get module key!'}"

  [[ -f "$(lib__state_manual_file "$key")" ]]
}

lib__state_clear_manual() {
  local key="${1:?'Do not get module key!'}"

  rm -f "$(lib__state_manual_file "$key")"
}

# external: the program was already present before the installer ran. The
# installer never treats it as its own and never removes it automatically.
lib__state_external_file() {
  local key="${1:?'Do not get module key!'}"

  printf '%s/external\n' "$(lib__state_module_dir "$key")"
}

lib__state_mark_external() {
  local key="${1:?'Do not get module key!'}"
  local file

  file="$(lib__state_external_file "$key")"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

lib__state_is_external() {
  local key="${1:?'Do not get module key!'}"

  [[ -f "$(lib__state_external_file "$key")" ]]
}

lib__state_clear_external() {
  local key="${1:?'Do not get module key!'}"

  rm -f "$(lib__state_external_file "$key")"
}

# Cleanup that could not finish yet. It is merged into the next successful
# run, so an interrupted cleanup is not lost when all module phases are done.
lib__cleanup_pending_file() {
  printf '%s/cleanup.pending\n' "$STATE_ROOT"
}

lib__cleanup_pending_load() {
  local file
  local kind
  local value

  CLEANUP_PENDING_PACKAGES=()
  CLEANUP_PENDING_MODULES=()

  file="$(lib__cleanup_pending_file)"
  [[ -f "$file" ]] || return 0

  while IFS=$'\t' read -r kind value; do
    [[ -n "$value" ]] || continue
    case "$kind" in
      package)
        CLEANUP_PENDING_PACKAGES+=("$value")
        ;;
      module)
        CLEANUP_PENDING_MODULES+=("$value")
        ;;
    esac
  done < "$file"
}

lib__cleanup_pending_track_package() {
  local package="${1:?'Do not get package name!'}"

  CLEANUP_PENDING_PACKAGES+=("$package")
}

lib__cleanup_pending_track_module() {
  local module="${1:?'Do not get module path!'}"

  CLEANUP_PENDING_MODULES+=("$module")
}

lib__cleanup_pending_write() {
  local file
  local package
  local module
  local tmp

  file="$(lib__cleanup_pending_file)"
  mkdir -p "$STATE_ROOT"
  tmp="$(mktemp "$STATE_ROOT/.cleanup.XXXXXX")"

  {
    for package in "${CLEANUP_PENDING_PACKAGES[@]}"; do
      printf 'package\t%s\n' "$package"
    done
    for module in "${CLEANUP_PENDING_MODULES[@]}"; do
      printf 'module\t%s\n' "$module"
    done
  } | awk -F '\t' 'NF == 2 && !seen[$0]++' > "$tmp"

  mv -f "$tmp" "$file"
  chmod 644 "$file"
}

lib__cleanup_pending_clear() {
  rm -f "$(lib__cleanup_pending_file)"
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

  if [[ "${MANIFEST_ACTIVE:-0}" -eq 1 ]]; then
    MANIFEST_STATUS='interrupted'
  fi

  trap - INT TERM

  if [[ -n "${CURRENT_STATE_KEY:-}" && -n "${CURRENT_STATE_PHASE:-}" ]]; then
    dir="$(lib__state_module_dir "$CURRENT_STATE_KEY")"
    rm -f "$dir/$CURRENT_STATE_PHASE.running"
    lib__state_write "$dir/$CURRENT_STATE_PHASE.failed" 'interrupted'
  fi

  lib__log_warn 'Interrupted.'
  exit 130
}

# Shared phase runner. Modules only write plain commands: the first failed
# command aborts the phase, output is streamed to the terminal and the phase
# log, and one detailed error line is printed by the runner.
_lib_state_run() {
  local key="${1:?'Dont get module key!'}"
  local phase="${2:?'Dont get phase!'}"
  local file="${3:?'Dont get module file!'}"
  local record_done="${4:?'Dont get record flag!'}"
  shift 4

  local dir
  local log
  local rc
  local fifo
  local errfile
  local tee_pid
  local errexit=0
  local detail=''

  case "$-" in
    *e*) errexit=1 ;;
  esac

  dir="$(lib__state_module_dir "$key")"
  log="$dir/$phase.log"
  mkdir -p "$dir"
  touch "$log"
  chmod 600 "$log"

  rm -f "$dir/$phase.done" "$dir/$phase.failed" "$dir/$phase.kept"
  lib__state_write "$dir/$phase.running" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  CURRENT_STATE_KEY="$key"
  CURRENT_STATE_PHASE="$phase"
  MODULE_STATE_DIR="$dir"
  MODULE_KEY="$key"
  trap 'lib__state_interrupt' INT TERM

  # A module runs in a subshell with errexit enabled, so the first failed
  # command fails the phase. Running it directly in a pipeline would disable
  # errexit and let a module report success after a failed build.
  fifo="$(mktemp -u "$dir/.phase.XXXXXX")"
  mkfifo "$fifo"
  errfile="$(mktemp "$dir/.err.XXXXXX")"

  tee -a "$log" < "$fifo" &
  tee_pid=$!

  # Phases must not ask questions. /dev/null makes a stray read fail fast
  # instead of waiting forever for input.
  set +e
  (
    set -eE -o pipefail

    LIB_PHASE_TMPROOT="$(mktemp -d)"
    trap 'rm -rf "$LIB_PHASE_TMPROOT"' EXIT
    trap 'printf "%s:%s: %s\n" "${BASH_SOURCE[0]##*/}" "$LINENO" "$BASH_COMMAND" > "$errfile"' ERR

    "$@"
  ) </dev/null > "$fifo" 2>&1
  rc=$?

  if [[ "$errexit" -eq 1 ]]; then
    set -e
  fi

  wait "$tee_pid" 2> /dev/null || true
  rm -f "$fifo"

  trap - INT TERM
  CURRENT_STATE_KEY=''
  CURRENT_STATE_PHASE=''

  rm -f "$dir/$phase.running"

  detail="$(<"$errfile")"
  rm -f "$errfile"

  if [[ "$rc" -eq 0 ]]; then
    if [[ "$record_done" -eq 1 ]]; then
      lib__state_write "$dir/$phase.done" "$(lib__state_fingerprint "$file")"
    fi
  elif [[ "$rc" -eq 3 ]]; then
    lib__state_write "$dir/$phase.kept" 'kept'
    printf '[WARN] %s: %s kept\n' "$MODULE_NAME" "$phase" \
      | tee -a "$log" >&2
  else
    lib__state_write "$dir/$phase.failed" "$(printf 'exit_code=%s\n%s' "$rc" "$detail")"
    printf '[ERROR] %s: %s failed: %s\n' "$MODULE_NAME" "$phase" "${detail:-exit_code=$rc}" \
      | tee -a "$log" >&2
  fi

  return "$rc"
}

# Install/configure phases are recorded with their fingerprint so a changed
# module file invalidates them.
lib__state_run_phase() {
  local key="${1:?'Dont get module key!'}"
  local phase="${2:?'Dont get phase!'}"
  local file="${3:?'Dont get module file!'}"
  shift 3

  _lib_state_run "$key" "$phase" "$file" 1 "$@"
}

# remove/deconfigure are actions: they have logs and failed markers, but no
# done marker. Their success is reflected by the install/configure state.
lib__state_run_action() {
  local key="${1:?'Dont get module key!'}"
  local phase="${2:?'Dont get phase!'}"
  local file="${3:?'Dont get module file!'}"
  shift 3

  _lib_state_run "$key" "$phase" "$file" 0 "$@"
}
