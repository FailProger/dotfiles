# Global settings and paths
source "$SCRIPT_DIR/config.sh"

# Imports
source "$SCRIPT_DIR/modules/imports.sh"

command__modules_in_dir() {
  local dir="${1:?'Do not get directory!'}"
  local file

  while IFS= read -r file; do
    basename "$file" .sh
  done < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -print | sort)
}

command__all_modules_in_dir() {
  local dir="${1:?'Do not get directory!'}"
  local file

  while IFS= read -r file; do
    basename "$file" .sh
  done < <(find "$dir" -type f -name '*.sh' -print | sort)
}

command__all_modules() {
  command__all_modules_in_dir "$SOFTWARE_DIR"
}

command__resolve_target() {
  local target="${1:?'Do not get target!'}"
  local dir
  local -a target_dirs=()

  if [[ "$target" == 'all' ]]; then
    command__all_modules
    return 0
  fi

  # Directories inside modules/software are groups; their children are
  # categories. A group installs every module below it, a category installs
  # only its direct modules.
  mapfile -t target_dirs < <(find "$SOFTWARE_DIR" -mindepth 1 -type d -name "$target" -print | sort)

  if [[ ${#target_dirs[@]} -eq 0 ]]; then
    echo "$target"
    return 0
  fi

  for dir in "${target_dirs[@]}"; do
    if [[ "$(dirname "$dir")" == "$SOFTWARE_DIR" ]]; then
      command__all_modules_in_dir "$dir"
    else
      command__modules_in_dir "$dir"
    fi
  done
}

command__list_modules() {
  local -a dirs=()
  local -a names=()
  local -a files=()
  local dir
  local rel_dir
  local top
  local category
  local name
  local current_top=''
  local total
  local name_width=0
  local category_width=0
  local cell
  local width
  local available
  local cols
  local rows
  local row
  local col
  local idx
  local index
  local first_in_group=1

  mapfile -t files < <(find "$SOFTWARE_DIR" -type f -name '*.sh' -print | sort)
  total=${#files[@]}

  mapfile -t dirs < <(find "$SOFTWARE_DIR" -type f -name '*.sh' -printf '%h\n' | sort -u)

  for dir in "${dirs[@]}"; do
    rel_dir="${dir#"$SOFTWARE_DIR"/}"
    category="${rel_dir#*/}"
    [[ "$category" == "$rel_dir" ]] && category="$rel_dir"

    (( ${#category} > category_width )) && category_width=${#category}

    while IFS= read -r name; do
      name="${name%.sh}"
      (( ${#name} > name_width )) && name_width=${#name}
    done < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -printf '%f\n')
  done

  printf '%sAvailable modules:%s %s\n' "$UI_BOLD" "$UI_RESET" "$total"

  width="$(lib__ui_width)"
  cell=$((name_width + 2))

  for dir in "${dirs[@]}"; do
    rel_dir="${dir#"$SOFTWARE_DIR"/}"
    top="${rel_dir%%/*}"
    category="${rel_dir#*/}"
    [[ "$category" == "$rel_dir" ]] && category="$rel_dir"

    if [[ "$top" != "$current_top" ]]; then
      printf '\n  %s%s%s\n' "$UI_BOLD$UI_CYAN" "$top" "$UI_RESET"
      current_top="$top"
      first_in_group=1
    fi

    if ((first_in_group == 0)); then
      printf '\n'
    fi
    first_in_group=0

    mapfile -t names < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort)
    for index in "${!names[@]}"; do
      names[$index]="${names[$index]%.sh}"
    done

    available=$((width - 4 - category_width - 2))
    cols=$((available / cell))
    ((cols < 1)) && cols=1
    rows=$(((${#names[@]} + cols - 1) / cols))

    for ((row = 0; row < rows; row++)); do
      if ((row == 0)); then
        printf '    %s%-*s%s  ' "$UI_CYAN" "$category_width" "$category" "$UI_RESET"
      else
        printf '%*s' $((4 + category_width + 2)) ''
      fi

      for ((col = 0; col < cols; col++)); do
        idx=$((row * cols + col))
        ((idx < ${#names[@]})) || continue

        if ((col == cols - 1 || idx == ${#names[@]} - 1)); then
          printf '%s' "${names[$idx]}"
        else
          printf '%-*s' "$cell" "${names[$idx]}"
        fi
      done

      printf '\n'
    done
  done
}

# Software is always installed for the user that runs the installer.
command__setup_environment() {
  local user
  local home

  user="$(id -un)"
  home="$(getent passwd "$user" | cut -d: -f6)"

  if [[ -z "$home" || ! -d "$home" ]]; then
    lib__log_error "Home directory for user '$user' not found."
    return 1
  fi

  USER="$user"
  HOME="$home"
  LOGNAME="$user"

  export USER HOME LOGNAME
}

command__confirm() {
  local answer

  while true; do
    if ! read -rp 'Continue? [Y/N] ' answer; then
      echo
      lib__log_error 'No input available; use -y to skip the confirmation.'
      return 1
    fi

    case "$answer" in
      Y|y|Yes|yes|YES)
        return 0
        ;;
      N|n|No|no|NO)
        echo 'Canceled.'
        return 1
        ;;
      *)
        lib__log_error 'Please enter Y or N.'
        ;;
    esac
  done
}

command_main() {
  local target
  local run_install=''
  local dry_run=0
  local install_only=0
  local configure_only=0
  local list_modules=0
  local mark_installed=0
  local reset=0
  local -a targets=()
  local -a modules=()

  UI_COLOR_MODE="${UI_COLOR:-auto}"

  trap 'lib__stop_sudo_keepalive; lib__state_unlock' EXIT

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        return 0
        ;;
      -y|--yes)
        run_install='yes'
        shift
        ;;
      -v|--verbose)
        INSTALL_VERBOSE=1
        shift
        ;;
      --color)
        if [[ $# -lt 2 || -z "$2" ]]; then
          lib__log_error "Option '$1' requires a value: auto, always or never."
          return 1
        fi
        UI_COLOR_MODE="$2"
        shift 2
        ;;
      --color=*)
        UI_COLOR_MODE="${1#*=}"
        if [[ -z "$UI_COLOR_MODE" ]]; then
          lib__log_error 'Option --color requires a value: auto, always or never.'
          return 1
        fi
        shift
        ;;
      -n|--dry-run)
        dry_run=1
        shift
        ;;
      -l|--list)
        list_modules=1
        shift
        ;;
      --install-only)
        install_only=1
        shift
        ;;
      --configure-only)
        configure_only=1
        shift
        ;;
      -f|--force)
        INSTALL_FORCE=1
        shift
        ;;
      -r|--reset)
        reset=1
        shift
        ;;
      -m|--mark-installed)
        mark_installed=1
        shift
        ;;
      --keep-going)
        INSTALL_KEEP_GOING=1
        shift
        ;;
      --)
        shift
        targets+=("$@")
        break
        ;;
      -*)
        lib__log_error "Unknown option: $1"
        return 1
        ;;
      *)
        targets+=("$1")
        shift
        ;;
    esac
  done

  lib__ui_init || return 1

  if [[ "$install_only" -eq 1 && "$configure_only" -eq 1 ]]; then
    lib__log_error '--install-only and --configure-only are mutually exclusive.'
    return 1
  fi

  if [[ "$mark_installed" -eq 1 && "$reset" -eq 1 ]]; then
    lib__log_error '--mark-installed and --reset are mutually exclusive.'
    return 1
  fi

  if [[ "$mark_installed" -eq 1 ]] \
    && [[ "$install_only" -eq 1 || "$configure_only" -eq 1 ]]; then
    lib__log_error '--mark-installed cannot be used with --install-only or --configure-only.'
    return 1
  fi

  if [[ "$list_modules" -eq 1 ]]; then
    command__list_modules
    return 0
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    lib__log_error 'Do not get modules to install!'
    return 1
  fi

  if [[ "$install_only" -eq 1 ]]; then
    INSTALL_MODE='install'
  elif [[ "$configure_only" -eq 1 ]]; then
    INSTALL_MODE='configure'
  fi

  INSTALL_DRY_RUN="$dry_run"

  command__setup_environment || return 1

  for target in "${targets[@]}"; do
    mapfile -t -O "${#modules[@]}" modules < <(command__resolve_target "$target")
  done

  if [[ ${#modules[@]} -eq 0 ]]; then
    lib__log_error 'No modules found.'
    return 1
  fi

  if [[ "$mark_installed" -eq 1 ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      queue_modules "${modules[@]}" || return 1
      lib__log_info 'Would mark as installed:'
      for module_file in "${INSTALL_REQUESTED[@]}"; do
        printf '  - %s\n' "$(basename "$module_file" .sh)"
      done
      return 0
    fi

    orchestrator__mark_installed "${modules[@]}" || return 1
    lib__log_success "Marked ${#INSTALL_REQUESTED[@]} module(s) as installed."
    return 0
  fi

  orchestrator__plan "${modules[@]}" || return 1
  lib__state_load

  if [[ "$reset" -eq 1 && "$dry_run" -eq 0 ]]; then
    orchestrator__reset
    lib__log_success "State removed for ${#INSTALL_REQUESTED[@]} module(s)."
    return 0
  fi

  if [[ "$reset" -eq 1 && "$dry_run" -eq 1 ]]; then
    lib__log_warn '--reset is ignored in dry-run mode.'
  fi

  orchestrator__print_plan

  if [[ "$dry_run" -eq 1 ]]; then
    return 0
  fi

  if ! orchestrator__has_pending_work; then
    lib__log_success 'Nothing to do: selected phases are already completed.'
    return 0
  fi

  if [[ -z "$run_install" ]]; then
    command__confirm || return 0
  fi

  orchestrator__run
}
