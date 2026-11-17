declare -a INSTALL_QUEUE=()
declare -a INSTALL_KEYS=()
declare -a INSTALL_NAMES=()
declare -a INSTALL_DEPENDENCIES=()
declare -a INSTALL_REQUESTED=()

declare -A REQUESTED_SET=()
declare -A _MODULE_VISITED=()
declare -A _MODULE_VISITING=()

# full | install | configure
INSTALL_MODE='full'
INSTALL_FORCE=0
INSTALL_KEEP_GOING=0
INSTALL_DRY_RUN=0
INSTALL_VERBOSE=0

_find_module_files() {
  local module_name="${1:?'Do not get module name!'}"

  find "$SOFTWARE_DIR" \
    -type f \
    -name "$module_name.sh" \
    -print
}

_module_key() {
  local module_file="${1:?'Do not get module file!'}"
  local relative="${module_file#"$SOFTWARE_DIR"/}"

  relative="${relative%.sh}"
  printf '%s\n' "${relative//\//__}"
}

_module_name() {
  local module_file="${1:?'Do not get module file!'}"

  basename "$module_file" .sh
}

# Short module name used in the plan: "cli/git" instead of
# "user-software__cli__git".
_module_display_name() {
  local module_file="${1:?'Do not get module file!'}"
  local relative="${module_file#"$SOFTWARE_DIR"/}"

  relative="${relative%.sh}"
  printf '%s\n' "${relative#*/}"
}

_module_dir_label() {
  local module_file="${1:?'Do not get module file!'}"
  local relative="${module_file#"$SOFTWARE_DIR"/}"

  relative="${relative%.sh}"
  printf '%s\n' "${relative%/*}"
}

queue_modules() {
  local module
  local module_file
  local -a queue=()
  local -a matches=()
  local -A seen_files=()

  if [[ $# -eq 0 ]]; then
    lib__log_error 'Do not get modules to install!'
    return 1
  fi

  for module in "$@"; do
    mapfile -t matches < <(_find_module_files "$module")

    if [[ ${#matches[@]} -eq 0 ]]; then
      lib__log_error "Module '$module' not found."
      return 1
    fi

    if [[ ${#matches[@]} -gt 1 ]]; then
      lib__log_error "Module name '$module' is ambiguous: ${matches[*]}"
      return 1
    fi

    module_file="$(realpath "${matches[0]}")"

    if [[ -n "${seen_files[$module_file]:-}" ]]; then
      continue
    fi

    seen_files["$module_file"]=1
    queue+=("$module_file")
  done

  INSTALL_REQUESTED=("${queue[@]}")
  REQUESTED_SET=()

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    REQUESTED_SET["$module_file"]=1
  done
}

# Collect module dependencies recursively. An entry from __get_dependencies
# that matches a module name is installed as a module; anything else is
# treated as an apt package.
_collect_module() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local dependency
  local dependency_file
  local -a dependency_matches=()

  module_file="$(realpath "$module_file")"

  if [[ -n "${_MODULE_VISITED[$module_file]:-}" ]]; then
    return 0
  fi

  if [[ -n "${_MODULE_VISITING[$module_file]:-}" ]]; then
    lib__log_error "Circular module dependency: $(_module_name "$module_file")"
    return 1
  fi

  _MODULE_VISITING["$module_file"]=1
  module="$(_module_name "$module_file")"

  # shellcheck disable=SC1090
  source "$module_file"

  if ! declare -F "${module}__get_dependencies" > /dev/null \
    || ! declare -F "${module}__install" > /dev/null \
    || ! declare -F "${module}__configure" > /dev/null; then
    lib__log_error "Module '$module' does not implement the module contract."
    return 1
  fi

  while IFS= read -r dependency; do
    dependency="${dependency//[[:space:]]/}"
    [[ -n "$dependency" ]] || continue

    dependency_file=''
    mapfile -t dependency_matches < <(_find_module_files "$dependency")

    if [[ ${#dependency_matches[@]} -gt 1 ]]; then
      lib__log_error "Dependency '$dependency' is ambiguous: ${dependency_matches[*]}"
      return 1
    fi

    if [[ ${#dependency_matches[@]} -eq 1 ]]; then
      # configure-only does not install module dependencies; requested
      # modules are still collected by the outer loop.
      if [[ "$INSTALL_MODE" == 'configure' ]]; then
        continue
      fi

      dependency_file="${dependency_matches[0]}"
      _collect_module "$dependency_file" || return 1
    else
      INSTALL_DEPENDENCIES+=("$dependency")
    fi
  done < <("${module}__get_dependencies")

  _MODULE_VISITING["$module_file"]=''
  _MODULE_VISITED["$module_file"]=1

  INSTALL_QUEUE+=("$module_file")
  INSTALL_KEYS+=("$(_module_key "$module_file")")
  INSTALL_NAMES+=("$module")
}

collect_modules() {
  local module_file

  INSTALL_QUEUE=()
  INSTALL_KEYS=()
  INSTALL_NAMES=()
  INSTALL_DEPENDENCIES=()
  _MODULE_VISITED=()
  _MODULE_VISITING=()

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    _collect_module "$module_file" || return 1
  done
}

orchestrator__plan() {
  queue_modules "$@" || return 1
  collect_modules || return 1
}

# Mark requested modules as installed. Only the install phase is marked;
# configure state is left as it is.
orchestrator__mark_installed() {
  local module_file
  local key
  local dir
  local fingerprint

  queue_modules "$@" || return 1

  lib__state_init
  lib__state_lock || return 1

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    key="$(_module_key "$module_file")"
    dir="$(lib__state_module_dir "$key")"
    fingerprint="$(lib__state_fingerprint "$module_file")"

    lib__state_module_init "$key" "$module_file"
    lib__state_write "$dir/install.done" "$fingerprint"
    rm -f "$dir/install.failed" "$dir/install.running"
  done

  lib__state_unlock
}

orchestrator__deps_enabled() {
  [[ "$INSTALL_MODE" != 'configure' ]]
}

# A module dependency (not explicitly requested) is installed without
# configuration. Explicitly requested modules use all phases for the mode.
orchestrator__phase_enabled() {
  local module_file="${1:?'Do not get module file!'}"
  local phase="${2:?'Do not get phase!'}"

  if [[ "$INSTALL_MODE" == 'configure' && -z "${REQUESTED_SET[$module_file]:-}" ]]; then
    return 1
  fi

  case "$phase" in
    install)
      [[ "$INSTALL_MODE" != 'configure' ]]
      ;;
    configure)
      [[ "$INSTALL_MODE" != 'install' ]] || return 1
      if [[ "$INSTALL_MODE" == 'full' && -z "${REQUESTED_SET[$module_file]:-}" ]]; then
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

orchestrator__mode_label() {
  case "$INSTALL_MODE" in
    install)
      printf 'install-only (deps + install)\n'
      ;;
    configure)
      printf 'configure-only\n'
      ;;
    *)
      printf 'full (deps + install + configure)\n'
      ;;
  esac
}

orchestrator__phase_status() {
  local key="${1:?'Do not get module key!'}"
  local phase="${2:?'Do not get phase!'}"
  local module_file="${3:?'Do not get module file!'}"

  if ! orchestrator__phase_enabled "$module_file" "$phase"; then
    printf 'skipped'
  elif [[ "$INSTALL_FORCE" -eq 1 ]]; then
    printf 'pending'
  elif lib__state_phase_done "$key" "$phase" "$module_file"; then
    printf 'done'
  else
    printf 'pending'
  fi
}

_module_has_pending() {
  local key="${1:?'Do not get module key!'}"
  local module_file="${2:?'Do not get module file!'}"

  if orchestrator__phase_enabled "$module_file" install \
    && [[ "$(orchestrator__phase_status "$key" install "$module_file")" == 'pending' ]]; then
    return 0
  fi

  if orchestrator__phase_enabled "$module_file" configure \
    && [[ "$(orchestrator__phase_status "$key" configure "$module_file")" == 'pending' ]]; then
    return 0
  fi

  return 1
}

_pending_phase_list() {
  local key="${1:?'Do not get module key!'}"
  local module_file="${2:?'Do not get module file!'}"
  local -a phases=()
  local index

  if orchestrator__phase_enabled "$module_file" install \
    && [[ "$(orchestrator__phase_status "$key" install "$module_file")" == 'pending' ]]; then
    phases+=('install')
  fi

  if orchestrator__phase_enabled "$module_file" configure \
    && [[ "$(orchestrator__phase_status "$key" configure "$module_file")" == 'pending' ]]; then
    phases+=('configure')
  fi

  printf '%s' "${phases[0]:-}"
  for ((index = 1; index < ${#phases[@]}; index++)); do
    printf ' + %s' "${phases[index]}"
  done
}

_status_icon() {
  case "$1" in
    done)
      printf '%s%s%s' "$UI_GREEN" "$UI_DONE" "$UI_RESET"
      ;;
    pending)
      printf '%s%s%s' "$UI_YELLOW" "$UI_TODO" "$UI_RESET"
      ;;
    skipped)
      printf '%s%s%s' "$UI_DIM" "$UI_SKIP" "$UI_RESET"
      ;;
    *)
      printf '%s%s%s' "$UI_RED" "$UI_FAIL" "$UI_RESET"
      ;;
  esac
}

# Full install/configure matrix used by --verbose.
orchestrator__print_plan_table() {
  local index
  local entry
  local module_file
  local key
  local label
  local rel_dir
  local current_dir=''
  local label_width=0
  local -a entries=()

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    label="${module_file##*/}"
    label="${label%.sh}"
    (( ${#label} > label_width )) && label_width=${#label}
    entries+=("$(_module_dir_label "$module_file")|$(printf '%03d' "$index")")
  done

  mapfile -t entries < <(printf '%s\n' "${entries[@]}" | sort)

  for entry in "${entries[@]}"; do
    rel_dir="${entry%|*}"
    index=$((10#${entry##*|}))
    module_file="${INSTALL_QUEUE[$index]}"
    key="${INSTALL_KEYS[$index]}"
    label="${module_file##*/}"
    label="${label%.sh}"

    if [[ "$rel_dir" != "$current_dir" ]]; then
      printf '\n  %s%s%s\n' "$UI_CYAN" "$rel_dir" "$UI_RESET"
      printf '    %-*s  %-8s%s\n' "$label_width" '' 'install' 'configure'
      current_dir="$rel_dir"
    fi

    if _module_has_pending "$key" "$module_file"; then
      printf '    %s%-*s%s  ' "$UI_BOLD" "$label_width" "$label" "$UI_RESET"
    else
      printf '    %s%-*s%s  ' "$UI_DIM" "$label_width" "$label" "$UI_RESET"
    fi

    _status_icon "$(orchestrator__phase_status "$key" install "$module_file")"
    printf '       '
    _status_icon "$(orchestrator__phase_status "$key" configure "$module_file")"
    printf '\n'
  done
}

orchestrator__print_plan() {
  local index
  local key
  local module_file
  local label
  local phases
  local label_width=0
  local pending_count
  local done_count
  local auto_count=0
  local dep_tag
  local -a pending_indices=()
  local -a done_indices=()

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    label="$(_module_display_name "$module_file")"
    (( ${#label} > label_width )) && label_width=${#label}

    if [[ -z "${REQUESTED_SET[$module_file]:-}" ]]; then
      auto_count=$((auto_count + 1))
    fi
  done

  printf '%-9s %s%s%s (uid %s)\n' 'User' "$UI_BOLD" "$USER" "$UI_RESET" "$UID"
  printf '%-9s %s\n' 'Home' "$HOME"
  printf '%-9s %s\n' 'State' "$(lib__ui_tilde_path "$STATE_ROOT")"
  printf '%-9s %s\n' 'Mode' "$(orchestrator__mode_label)"

  if [[ "$INSTALL_MODE" == 'full' && "$auto_count" -gt 0 ]]; then
    printf '%-9s %smodule dependencies: install only%s\n' 'Deps' "$UI_DIM" "$UI_RESET"
  fi

  if [[ "$INSTALL_FORCE" -eq 1 ]]; then
    printf '%-9s %syes, saved phase state is ignored%s\n' 'Force' "$UI_YELLOW" "$UI_RESET"
  fi

  if [[ "$INSTALL_DRY_RUN" -eq 1 ]]; then
    printf '%-9s %syes, nothing will be changed%s\n' 'Dry run' "$UI_YELLOW" "$UI_RESET"
  fi

  for index in "${!INSTALL_QUEUE[@]}"; do
    key="${INSTALL_KEYS[$index]}"
    module_file="${INSTALL_QUEUE[$index]}"

    if _module_has_pending "$key" "$module_file"; then
      pending_indices+=("$index")
    else
      done_indices+=("$index")
    fi
  done

  pending_count=${#pending_indices[@]}
  done_count=${#done_indices[@]}

  printf '\nModules: %s requested' "$(( ${#INSTALL_QUEUE[@]} - auto_count ))"
  if ((auto_count == 1)); then
    printf ' + %s1 dependency%s' "$UI_DIM" "$UI_RESET"
  elif ((auto_count > 1)); then
    printf ' + %s%s dependencies%s' "$UI_DIM" "$auto_count" "$UI_RESET"
  fi
  if ((pending_count > 0)); then
    printf ' · %s%s done%s' "$UI_GREEN" "$done_count" "$UI_RESET"
    printf ' · %s%s pending%s' "$UI_YELLOW" "$pending_count" "$UI_RESET"
  else
    printf ' · %sall done%s' "$UI_GREEN" "$UI_RESET"
  fi
  printf '\n'

  if [[ "$INSTALL_VERBOSE" -eq 1 ]]; then
    orchestrator__print_plan_table
  elif ((pending_count > 0)); then
    printf '\n  %sWill run (%s)%s\n' "$UI_BOLD$UI_YELLOW" "$pending_count" "$UI_RESET"

    for index in "${pending_indices[@]}"; do
      key="${INSTALL_KEYS[$index]}"
      module_file="${INSTALL_QUEUE[$index]}"
      label="$(_module_display_name "$module_file")"
      phases="$(_pending_phase_list "$key" "$module_file")"
      dep_tag=''
      if [[ -z "${REQUESTED_SET[$module_file]:-}" ]]; then
        dep_tag=" ${UI_DIM}(dependency)${UI_RESET}"
      fi

      printf '    %s%s%s %s%-*s%s  %s%s%s%s\n' \
        "$UI_YELLOW" "$UI_ARROW" "$UI_RESET" \
        "$UI_BOLD" "$label_width" "$label" "$UI_RESET" \
        "$UI_DIM" "$phases" "$UI_RESET" "$dep_tag"
    done

    if ((done_count > 0)); then
      printf '\n  %sAlready done (%s)%s\n' "$UI_DIM" "$done_count" "$UI_RESET"

      for index in "${done_indices[@]}"; do
        module_file="${INSTALL_QUEUE[$index]}"
        label="$(_module_display_name "$module_file")"
        dep_tag=''
        if [[ -z "${REQUESTED_SET[$module_file]:-}" ]]; then
          dep_tag=" ${UI_DIM}(dependency)${UI_RESET}"
        fi

        printf '    %s%s %s%s%s\n' "$UI_DIM" "$UI_DONE" "$label" "$UI_RESET" "$dep_tag"
      done
    fi
  fi

  printf '\n'
  if orchestrator__deps_enabled; then
    lib__apt_print_dependencies "$INSTALL_VERBOSE" "${INSTALL_DEPENDENCIES[@]}"
  else
    printf '  %sDependencies:%s %sskipped (configure-only)%s\n' \
      "$UI_BOLD" "$UI_RESET" "$UI_DIM" "$UI_RESET"
  fi
  printf '\n'
}

orchestrator__reset() {
  local module_file

  lib__state_load

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    lib__state_reset "$(_module_key "$module_file")"
  done
}

orchestrator__should_skip() {
  local key="${1:?'Do not get module key!'}"
  local phase="${2:?'Do not get phase!'}"
  local module_file="${3:?'Do not get module file!'}"

  if [[ "$INSTALL_FORCE" -eq 1 ]]; then
    return 1
  fi

  lib__state_phase_done "$key" "$phase" "$module_file"
}

# Return 0 when at least one selected phase or dependency still needs work.
orchestrator__has_pending_work() {
  local index
  local key
  local module_file
  local dependency

  if orchestrator__deps_enabled; then
    for dependency in "${INSTALL_DEPENDENCIES[@]}"; do
      if ! lib__apt_is_installed "$dependency"; then
        return 0
      fi
    done
  fi

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    key="${INSTALL_KEYS[$index]}"

    if orchestrator__phase_enabled "$module_file" install \
      && ! orchestrator__should_skip "$key" install "$module_file"; then
      return 0
    fi

    if orchestrator__phase_enabled "$module_file" configure \
      && ! orchestrator__should_skip "$key" configure "$module_file"; then
      return 0
    fi
  done

  return 1
}

orchestrator__print_resume() {
  local -a failed_entries=("$@")
  local entry
  local module_file
  local -a flags=()
  local -a names=()

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    names+=("$(_module_name "$module_file")")
  done

  flags=(-y)

  case "$INSTALL_MODE" in
    install)
      flags+=(--install-only)
      ;;
    configure)
      flags+=(--configure-only)
      ;;
  esac

  if [[ "$INSTALL_KEEP_GOING" -eq 1 ]]; then
    flags+=(--keep-going)
  fi

  echo 'Failed phases:'
  for entry in "${failed_entries[@]}"; do
    printf '  %s%s%s %s (%s)\n' "$UI_RED" "$UI_FAIL" "$UI_RESET" "${entry%%:*}" "${entry##*:}"
  done

  echo
  echo 'To resume, run:'
  printf '  ./installer.sh'
  printf ' %q' "${flags[@]}" "${names[@]}"
  echo
}

orchestrator__run() {
  local index
  local module_file
  local key
  local module
  local -a failed_entries=()
  local failed=0

  lib__state_init
  lib__state_lock || return 1

  if orchestrator__deps_enabled && [[ ${#INSTALL_DEPENDENCIES[@]} -gt 0 ]]; then
    if ! lib__apt_install "${INSTALL_DEPENDENCIES[@]}" </dev/null; then
      failed=1
      failed_entries+=('deps:apt')
      if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
        lib__state_unlock
        orchestrator__print_resume "${failed_entries[@]}"
        return 1
      fi
    fi
  fi

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    key="${INSTALL_KEYS[$index]}"
    module="${INSTALL_NAMES[$index]}"

    # Once sudo credentials are cached (for example after the first phase),
    # keep them fresh from the main process.
    if [[ $EUID -ne 0 ]] && sudo -n true 2> /dev/null; then
      lib__start_sudo_keepalive
    fi

    # shellcheck disable=SC1090
    source "$module_file"

    lib__state_module_init "$key" "$module_file"

    if orchestrator__phase_enabled "$module_file" install; then
      if orchestrator__should_skip "$key" install "$module_file"; then
        lib__log_info "$key: install already done, skipping."
      elif ! lib__state_run_phase "$key" install "$module_file" "${module}__install"; then
        failed=1
        failed_entries+=("$module:install")
        if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
          break
        fi
        continue
      fi
    fi

    if orchestrator__phase_enabled "$module_file" configure; then
      if orchestrator__should_skip "$key" configure "$module_file"; then
        lib__log_info "$key: configure already done, skipping."
      elif ! lib__state_run_phase "$key" configure "$module_file" "${module}__configure"; then
        failed=1
        failed_entries+=("$module:configure")
        if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
          break
        fi
      fi
    fi
  done

  lib__state_unlock

  if [[ "$failed" -eq 0 ]]; then
    lib__log_success 'All selected modules are installed.'
    return 0
  fi

  lib__log_error 'Installation finished with errors.'
  orchestrator__print_resume "${failed_entries[@]}"
  return 1
}
