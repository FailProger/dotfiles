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

# Status shown by list: "done" once the install phase is recorded for the
# current module fingerprint, or when the program is present outside the
# installer.
command__module_status() {
  local module_file="${1:?'Do not get module file!'}"
  local key

  key="$(_module_key "$module_file")"

  if lib__state_phase_done "$key" install "$module_file" \
    || lib__state_is_external "$key"; then
    printf 'done\n'
    return 0
  fi

  # The list does not preload modules, so load the file to make the optional
  # __is_installed hook available. This runs in a command substitution, so the
  # functions do not leak into the parent shell.
  # shellcheck disable=SC1090
  if source "$module_file" 2> /dev/null && _module_is_present "$module_file"; then
    printf 'done\n'
  else
    printf 'pending\n'
  fi
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
  local module_file
  local status
  local status_color
  local status_icon

  lib__state_load

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
  cell=$((name_width + 4))

  for dir in "${dirs[@]}"; do
    rel_dir="${dir#"$SOFTWARE_DIR"/}"
    top="${rel_dir%%/*}"
    category="${rel_dir#*/}"
    [[ "$category" == "$rel_dir" ]] && category="$rel_dir"

    if [[ "$top" != "$current_top" ]]; then
      printf '\n  %s%s%s\n' "$UI_BOLD$UI_YELLOW" "$top" "$UI_RESET"
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
        printf '    %s%-*s%s  ' "$UI_BOLD$UI_YELLOW" "$category_width" "$category" "$UI_RESET"
      else
        printf '%*s' $((4 + category_width + 2)) ''
      fi

      for ((col = 0; col < cols; col++)); do
        idx=$((row * cols + col))
        ((idx < ${#names[@]})) || continue

        name="${names[$idx]}"
        module_file="$dir/$name.sh"
        status="$(command__module_status "$module_file")"

        if [[ "$status" == 'done' ]]; then
          status_color="$UI_GREEN"
          status_icon="$UI_DONE"
        else
          status_color="$UI_DIM"
          status_icon="$UI_TODO"
        fi

        if ((col == cols - 1 || idx == ${#names[@]} - 1)); then
          printf '%s %s%s%s' "$name" "$status_color" "$status_icon" "$UI_RESET"
        else
          printf '%s %s%s%s%*s' "$name" "$status_color" "$status_icon" "$UI_RESET" \
            "$((cell - ${#name} - 2))" ''
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

command__usage() {
  cat << EOF
Usage: ./$(basename "$0") [OPTIONS] COMMAND [COMMAND OPTIONS] TARGET...

COMMANDS:
  install      Install modules and their dependencies.
  configure    Run only __configure for installed modules.
  reinstall    Force __install and __configure again.
  remove       Run __remove: remove the program, keep configuration.
  deconfigure  Run __deconfigure: remove configuration, keep the program.
  list         List all available modules and their state.

TARGETS:
  MODULE       A single module.
  CATEGORY     Every module in a category under a group.
  GROUP        Every module in a group.
  all          Every module.

GLOBAL OPTIONS:
  -h, --help            Show this help and exit.
  -y, --yes             Skip the confirmation prompt.
  -d, --dry-run         Show the plan without changing anything.
  -v, --verbose         Detailed plan: phases, packages and descriptions.
      --color WHEN      Color output: auto, always or never (default: auto).
      --keep-going      Continue with the remaining modules after a failure.

INSTALL/REINSTALL OPTIONS:
      --keep-build-deps Keep build dependencies and build-only modules.
      --force-clean     Run apt autoremove even if a module failed.

INSTALL OPTIONS:
      --no-configure    Install the program only; do not run __configure.

REMOVE OPTIONS:
      --deconfigure     Also run __deconfigure after a successful __remove.

EXAMPLES:
  ./installer.sh install zsh
  ./installer.sh -d install all
  ./installer.sh install --keep-build-deps dwm
  ./installer.sh configure zsh
  ./installer.sh reinstall zsh
  ./installer.sh remove zsh
  ./installer.sh deconfigure zsh
  ./installer.sh remove --deconfigure zsh
  ./installer.sh list

NOTES:
  Software is installed for the user who runs the script.
  Root operations ask for sudo only when they are needed.
  Running the script as root installs software for root, not for the
  current desktop user; normally run it without sudo.
EOF
}

command_main() {
  if [[ $# -eq 0 ]]; then
    command__usage
    return 0
  fi

  local target
  local action=''
  local run_install=''
  local dry_run=0
  local no_configure=0
  local remove_deconfigure=0
  local -a targets=()
  local -a modules=()
  local -a argv=()
  local arg
  local index
  local expand_short=1

  UI_COLOR_MODE="${UI_COLOR:-auto}"

  trap 'rc=$?; lib__manifest_exit || true; lib__stop_sudo_keepalive; lib__state_unlock; exit "$rc"' EXIT

  # Accept bundled short options such as -vd or -yd. Only single-dash
  # alphabetic bundles are expanded; long options and values stay untouched.
  for arg in "$@"; do
    if [[ "$expand_short" -eq 0 ]]; then
      argv+=("$arg")
    elif [[ "$arg" == '--' ]]; then
      expand_short=0
      argv+=("$arg")
    elif [[ "$arg" =~ ^-[[:alpha:]]{2,}$ ]]; then
      for ((index = 1; index < ${#arg}; index++)); do
        argv+=("-${arg:$index:1}")
      done
    else
      argv+=("$arg")
    fi
  done

  if [[ ${#argv[@]} -gt 0 ]]; then
    set -- "${argv[@]}"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        command__usage
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
      -d|--dry-run)
        dry_run=1
        shift
        ;;
      --keep-going)
        INSTALL_KEEP_GOING=1
        shift
        ;;
      --keep-build-deps)
        INSTALL_KEEP_BUILD_DEPS=1
        shift
        ;;
      --force-clean)
        INSTALL_FORCE_CLEAN=1
        shift
        ;;
      --no-configure)
        no_configure=1
        shift
        ;;
      --deconfigure)
        remove_deconfigure=1
        shift
        ;;
      install|configure|reinstall|remove|deconfigure|list)
        if [[ -n "$action" ]]; then
          lib__log_error "Only one command is allowed: '$action' and '$1'."
          return 1
        fi
        action="$1"
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

  if [[ -z "$action" ]]; then
    if [[ ${#targets[@]} -gt 0 ]]; then
      lib__log_error "Unknown command: ${targets[0]}"
      lib__log_error "Did you mean: ./$(basename "$0") install ${targets[*]}"
    else
      lib__log_error 'Do not get command!'
    fi
    return 1
  fi

  if [[ "$action" == 'list' ]]; then
    if [[ ${#targets[@]} -gt 0 ]]; then
      lib__log_error 'list does not accept targets.'
      return 1
    fi
    command__list_modules
    return 0
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    lib__log_error "Do not get modules for '$action'!"
    return 1
  fi

  if [[ "$action" != 'install' && "$action" != 'reinstall' ]]; then
    if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 ]]; then
      lib__log_error '--keep-build-deps is only valid for install and reinstall.'
      return 1
    fi
    if [[ "$INSTALL_FORCE_CLEAN" -eq 1 ]]; then
      lib__log_error '--force-clean is only valid for install and reinstall.'
      return 1
    fi
  fi

  if [[ "$action" != 'install' && "$no_configure" -eq 1 ]]; then
    lib__log_error '--no-configure is only valid for install.'
    return 1
  fi

  if [[ "$action" != 'remove' && "$remove_deconfigure" -eq 1 ]]; then
    lib__log_error '--deconfigure is only valid for remove.'
    return 1
  fi

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 && "$INSTALL_FORCE_CLEAN" -eq 1 ]]; then
    lib__log_error '--keep-build-deps and --force-clean are mutually exclusive.'
    return 1
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

  case "$action" in
    install)
      if [[ "$no_configure" -eq 1 ]]; then
        INSTALL_MODE='install'
      else
        INSTALL_MODE='full'
      fi
      ;;
    configure)
      INSTALL_MODE='configure'
      INSTALL_KEEP_BUILD_DEPS=0
      INSTALL_FORCE_CLEAN=0
      ;;
    reinstall)
      INSTALL_MODE='full'
      INSTALL_FORCE=1
      ;;
    remove|deconfigure)
      if [[ "$action" == 'deconfigure' ]]; then
        REMOVE_PROGRAM=0
        REMOVE_CONFIG=1
      else
        REMOVE_PROGRAM=1
        REMOVE_CONFIG="$remove_deconfigure"
      fi
      orchestrator__remove_plan "${modules[@]}" || return 1
      orchestrator__print_remove_plan
      if [[ "$dry_run" -eq 1 ]]; then
        return 0
      fi
      if [[ ${#REMOVE_BLOCKED[@]} -gt 0 ]]; then
        return 1
      fi
      if [[ -z "$run_install" ]]; then
        command__confirm || return 0
      fi
      orchestrator__remove_run
      return $?
      ;;
  esac

  orchestrator__plan "${modules[@]}" || return 1
  lib__state_load
  orchestrator__prepare_dependency_sets

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
