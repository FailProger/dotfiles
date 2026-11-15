# Terminal output helpers: colors, icons, widths and simple layouts.

UI_COLOR_MODE='auto'

UI_RESET=''
UI_BOLD=''
UI_DIM=''
UI_RED=''
UI_GREEN=''
UI_YELLOW=''
UI_CYAN=''

UI_DONE='+'
UI_TODO='.'
UI_SKIP='-'
UI_FAIL='x'
UI_ARROW='>'
UI_ADD='+'
UI_OK='+'
UI_UNKNOWN='?'
UI_ELLIPSIS='...'

# Initialize colors and icons. Colors are disabled when stdout is not a TTY,
# unless UI_COLOR_MODE is "always". NO_COLOR and TERM=dumb are honored.
lib__ui_init() {
  local mode="${UI_COLOR_MODE:-auto}"
  local locale
  local use_color=0

  case "$mode" in
    always)
      use_color=1
      ;;
    never)
      ;;
    auto)
      if [[ -z "${NO_COLOR:-}" && "${TERM:-}" != 'dumb' && -t 1 ]]; then
        use_color=1
      fi
      ;;
    *)
      printf '[ERROR] Invalid color mode: %s\n' "$mode" >&2
      return 1
      ;;
  esac

  if ((use_color)); then
    UI_RESET=$'\033[0m'
    UI_BOLD=$'\033[1m'
    UI_DIM=$'\033[2m'
    UI_RED=$'\033[31m'
    UI_GREEN=$'\033[32m'
    UI_YELLOW=$'\033[33m'
    UI_CYAN=$'\033[36m'
  fi

  locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  case "$locale" in
    *UTF-8*|*utf8*|*UTF8*)
      UI_DONE='✓'
      UI_TODO='·'
      UI_SKIP='–'
      UI_FAIL='✗'
      UI_ARROW='→'
      UI_ADD='+'
      UI_OK='✓'
      UI_UNKNOWN='?'
      UI_ELLIPSIS='…'
      ;;
  esac
}

# Return 0 when color output is allowed for the given file descriptor.
lib__ui_color_for() {
  local fd="${1:-1}"

  case "$UI_COLOR_MODE" in
    always)
      return 0
      ;;
    never)
      return 1
      ;;
    *)
      [[ -z "${NO_COLOR:-}" && "${TERM:-}" != 'dumb' ]] && [[ -t "$fd" ]]
      ;;
  esac
}

# Usable output width, even when stdout is redirected.
lib__ui_width() {
  local width="${COLUMNS:-}"

  if [[ ! "$width" =~ ^[0-9]+$ ]]; then
    width=''
    if [[ -t 1 ]]; then
      width="$(tput cols 2> /dev/null || true)"
    fi
  fi

  [[ "$width" =~ ^[0-9]+$ ]] || width=80
  ((width < 40)) && width=40

  printf '%s\n' "$width"
}

# Replace the leading home directory with a tilde.
lib__ui_tilde_path() {
  local path="${1:-}"

  if [[ -n "${HOME:-}" && ( "$path" == "$HOME" || "$path" == "$HOME"/* ) ]]; then
    printf '~%s\n' "${path#"$HOME"}"
  else
    printf '%s\n' "$path"
  fi
}

# Truncate text to at most MAX visible characters.
lib__ui_truncate() {
  local max="${1:?}"
  local text="${2:-}"

  ((max <= 0)) && return 0

  if (( ${#text} <= max )); then
    printf '%s' "$text"
  elif (( max > ${#UI_ELLIPSIS} )); then
    printf '%s%s' "${text:0:$((max - ${#UI_ELLIPSIS}))}" "$UI_ELLIPSIS"
  else
    printf '%s' "${text:0:max}"
  fi
}
