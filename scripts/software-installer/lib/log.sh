lib__log_error() {
  local message="${1:?'Dont get log message!'}"

  if lib__ui_color_for 2; then
    printf '%s[ERROR]%s %s\n' "$UI_RED" "$UI_RESET" "$message" >&2
  else
    printf '[ERROR] %s\n' "$message" >&2
  fi
}

lib__log_warn() {
  local message="${1:?'Dont get log message!'}"

  if lib__ui_color_for 2; then
    printf '%s[WARN]%s %s\n' "$UI_YELLOW" "$UI_RESET" "$message" >&2
  else
    printf '[WARN] %s\n' "$message" >&2
  fi
}

lib__log_info() {
  local message="${1:?'Dont get log message!'}"

  if lib__ui_color_for 1; then
    printf '%s[INFO]%s %s\n' "$UI_CYAN" "$UI_RESET" "$message"
  else
    printf '[INFO] %s\n' "$message"
  fi
}

lib__log_success() {
  local message="${1:?'Dont get log message!'}"

  if lib__ui_color_for 1; then
    printf '%s[ OK ]%s %s\n' "$UI_GREEN" "$UI_RESET" "$message"
  else
    printf '[ OK ] %s\n' "$message"
  fi
}
