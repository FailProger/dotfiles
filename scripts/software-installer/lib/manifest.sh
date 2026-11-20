# JSON run manifest. The orchestrator fills these arrays and the EXIT trap
# writes the file even when the run fails or is interrupted.

MANIFEST_ACTIVE=0
MANIFEST_TIMESTAMP=''
MANIFEST_DIR=''
MANIFEST_STATUS='running'

MANIFEST_KEEP_BUILD_DEPS=0
MANIFEST_FORCE_CLEAN=0
MANIFEST_AUTOREMOVE_RAN=0
MANIFEST_PENDING_CLEANUP_PROCESSED=0

declare -ga MANIFEST_MODULES_REQUESTED=()
declare -ga MANIFEST_MODULES_SUCCEEDED=()
declare -ga MANIFEST_MODULES_FAILED=()
declare -ga MANIFEST_MODULES_SKIPPED=()
declare -ga MANIFEST_MODULES_REMOVED=()
declare -ga MANIFEST_MODULES_KEPT=()
declare -ga MANIFEST_BUILD_ALL=()
declare -ga MANIFEST_RUNTIME_ALL=()
declare -ga MANIFEST_BUILD_ONLY=()
declare -ga MANIFEST_MANUAL_BEFORE=()
declare -ga MANIFEST_INSTALLED_BY_US=()
declare -ga MANIFEST_AUTO_MARKED=()
declare -ga MANIFEST_AUTOREMOVE_PREVIEW=()
declare -ga MANIFEST_AUTOREMOVE_REMOVED=()

lib__manifest_begin() {
  local stamp

  MANIFEST_ACTIVE=1
  MANIFEST_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  MANIFEST_STATUS='running'

  mkdir -p "$STATE_ROOT/manifests"
  MANIFEST_DIR="$(mktemp -d "$STATE_ROOT/manifests/${stamp}.XXXXXX")"
  chmod 700 "$MANIFEST_DIR"

  MANIFEST_MODULES_REQUESTED=()
  MANIFEST_MODULES_SUCCEEDED=()
  MANIFEST_MODULES_FAILED=()
  MANIFEST_MODULES_SKIPPED=()
  MANIFEST_MODULES_REMOVED=()
  MANIFEST_MODULES_KEPT=()
  MANIFEST_BUILD_ALL=()
  MANIFEST_RUNTIME_ALL=()
  MANIFEST_BUILD_ONLY=()
  MANIFEST_MANUAL_BEFORE=()
  MANIFEST_INSTALLED_BY_US=()
  MANIFEST_AUTO_MARKED=()
  MANIFEST_AUTOREMOVE_PREVIEW=()
  MANIFEST_AUTOREMOVE_REMOVED=()
}

_lib__manifest_json_array() {
  local first=1
  local value

  printf '['
  for value in "$@"; do
    [[ -n "$value" ]] || continue
    if ((first)); then
      first=0
    else
      printf ', '
    fi
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
  done
  printf ']'
}

_lib__manifest_field_array() {
  local field="$1"
  local -n values="$2"

  printf '  "%s": ' "$field"
  _lib__manifest_json_array "${values[@]}"
  printf ',\n'
}

_lib__manifest_bool() {
  if [[ "$1" -eq 1 ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

lib__manifest_write() {
  local file
  local tmp

  if [[ -z "${MANIFEST_DIR:-}" ]]; then
    return 0
  fi

  file="$MANIFEST_DIR/manifest.json"
  tmp="$(mktemp "$MANIFEST_DIR/.manifest.XXXXXX")"

  {
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$MANIFEST_TIMESTAMP"
    printf '  "status": "%s",\n' "$MANIFEST_STATUS"
    _lib__manifest_field_array 'modules_requested' MANIFEST_MODULES_REQUESTED
    _lib__manifest_field_array 'modules_succeeded' MANIFEST_MODULES_SUCCEEDED
    _lib__manifest_field_array 'modules_failed' MANIFEST_MODULES_FAILED
    _lib__manifest_field_array 'modules_skipped' MANIFEST_MODULES_SKIPPED
    _lib__manifest_field_array 'modules_removed' MANIFEST_MODULES_REMOVED
    _lib__manifest_field_array 'modules_kept' MANIFEST_MODULES_KEPT
    _lib__manifest_field_array 'build_all' MANIFEST_BUILD_ALL
    _lib__manifest_field_array 'runtime_all' MANIFEST_RUNTIME_ALL
    _lib__manifest_field_array 'build_only' MANIFEST_BUILD_ONLY
    _lib__manifest_field_array 'manual_before' MANIFEST_MANUAL_BEFORE
    _lib__manifest_field_array 'installed_by_us' MANIFEST_INSTALLED_BY_US
    _lib__manifest_field_array 'auto_marked' MANIFEST_AUTO_MARKED
    _lib__manifest_field_array 'autoremove_preview' MANIFEST_AUTOREMOVE_PREVIEW
    _lib__manifest_field_array 'autoremove_removed' MANIFEST_AUTOREMOVE_REMOVED
    printf '  "autoremove_ran": %s,\n' "$(_lib__manifest_bool "$MANIFEST_AUTOREMOVE_RAN")"
    printf '  "keep_build_deps": %s,\n' "$(_lib__manifest_bool "$MANIFEST_KEEP_BUILD_DEPS")"
    printf '  "force_clean": %s,\n' "$(_lib__manifest_bool "$MANIFEST_FORCE_CLEAN")"
    printf '  "pending_cleanup_processed": %s\n' "$(_lib__manifest_bool "$MANIFEST_PENDING_CLEANUP_PROCESSED")"
    printf '}\n'
  } > "$tmp"

  mv -f "$tmp" "$file"
  chmod 600 "$file"
}

lib__manifest_exit() {
  if [[ "${MANIFEST_ACTIVE:-0}" -ne 1 ]]; then
    return 0
  fi

  if [[ "$MANIFEST_STATUS" == 'running' ]]; then
    if [[ ${#MANIFEST_MODULES_FAILED[@]} -gt 0 ]]; then
      MANIFEST_STATUS='failed'
    else
      MANIFEST_STATUS='success'
    fi
  fi

  lib__manifest_write || true
  MANIFEST_ACTIVE=0
}
