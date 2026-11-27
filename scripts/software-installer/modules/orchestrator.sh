declare -a INSTALL_QUEUE=()
declare -a INSTALL_KEYS=()
declare -a INSTALL_NAMES=()
declare -a INSTALL_REQUESTED=()

declare -A REQUESTED_SET=()
declare -A _MODULE_VISITED=()
declare -A _MODULE_VISITING=()

# Per-module dependency declarations. Values are newline-separated lists.
declare -A MODULE_BUILD_PACKAGES=()
declare -A MODULE_RUNTIME_PACKAGES=()
declare -A MODULE_BUILD_MODULES=()
declare -A MODULE_RUNTIME_MODULES=()
declare -A MODULE_ROLE=()
declare -A MODULE_ACTIVE_INSTALL=()

# Removal/deconfiguration plan.
declare -a REMOVE_MODULES=()
declare -a REMOVE_NAMES=()
declare -a REMOVE_KEYS=()
declare -a REMOVE_BLOCKED=()
declare -a REMOVE_SKIPPED=()
declare -a REMOVE_REMOVED=()
declare -a REMOVE_DECONFIGURED=()
declare -a REMOVE_KEPT=()
declare -a REMOVE_FAILED=()
REMOVE_PROGRAM=1
REMOVE_CONFIG=0

# Dependency sets.
declare -a INSTALL_BUILD_ALL=()
declare -a INSTALL_RUNTIME_ALL=()
declare -a INSTALL_BUILD_FOR_RUN=()
declare -a INSTALL_RUNTIME_FOR_RUN=()
declare -a INSTALL_BUILD_ONLY=()
declare -a INSTALL_BUILD_ONLY_MODULES=()

# apt snapshots used by the manifest and by cleanup decisions.
declare -a APT_MANUAL_BEFORE=()
declare -a APT_INSTALLED_BEFORE=()
declare -a APT_INSTALLED_AFTER=()
declare -a APT_INSTALLED_BEFORE_CLEANUP=()
declare -a APT_INSTALLED_AFTER_CLEANUP=()
declare -a APT_INSTALLED_BY_US=()
declare -a APT_AUTOREMOVE_PREVIEW=()
declare -a APT_AUTOREMOVE_REMOVED=()
declare -A APT_MANUAL_BEFORE_SET=()

# Run outcome.
declare -a INSTALL_SUCCEEDED=()
declare -a INSTALL_FAILED=()
declare -a INSTALL_SKIPPED=()
declare -a INSTALL_REMOVED=()
declare -a INSTALL_KEPT_BUILD_ONLY=()
declare -A _MODULE_FAILED=()
declare -A _MODULE_SKIPPED=()

# full | install | configure
INSTALL_MODE='full'
INSTALL_FORCE=0
INSTALL_KEEP_GOING=0
INSTALL_DRY_RUN=0
INSTALL_VERBOSE=0
INSTALL_KEEP_BUILD_DEPS=0
INSTALL_FORCE_CLEAN=0

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

# Split a newline-separated dependency string into unique package/module names.
_module_deps_from_string() {
  local value="${1:-}"

  printf '%s\n' "$value" | awk 'NF && !seen[$0]++'
}

_array_add_unique() {
  local -n target="$1"
  shift

  local -A seen=()
  local value

  for value in "${target[@]}"; do
    [[ -n "$value" ]] && seen["$value"]=1
  done

  for value in "$@"; do
    [[ -n "$value" ]] || continue
    [[ -n "${seen[$value]:-}" ]] && continue
    seen["$value"]=1
    target+=("$value")
  done
}

_array_dedupe() {
  local -n target="$1"

  local -a result=()
  local -A seen=()
  local value

  for value in "${target[@]}"; do
    [[ -n "$value" ]] || continue
    [[ -n "${seen[$value]:-}" ]] && continue
    seen["$value"]=1
    result+=("$value")
  done

  target=("${result[@]}")
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

_append_module_package() {
  local map_name="$1"
  local module_file="$2"
  local package="$3"

  if [[ "$map_name" == 'build' ]]; then
    MODULE_BUILD_PACKAGES["$module_file"]="${MODULE_BUILD_PACKAGES[$module_file]:-}$package"$'\n'
  else
    MODULE_RUNTIME_PACKAGES["$module_file"]="${MODULE_RUNTIME_PACKAGES[$module_file]:-}$package"$'\n'
  fi
}

_append_module_dependency() {
  local map_name="$1"
  local module_file="$2"
  local dependency_file="$3"

  if [[ "$map_name" == 'build' ]]; then
    MODULE_BUILD_MODULES["$module_file"]="${MODULE_BUILD_MODULES[$module_file]:-}$dependency_file"$'\n'
  else
    MODULE_RUNTIME_MODULES["$module_file"]="${MODULE_RUNTIME_MODULES[$module_file]:-}$dependency_file"$'\n'
  fi
}

_collect_dependency_list() {
  local map_name="$1"
  local module_file="$2"
  local raw="$3"
  local dependency
  local dependency_file
  local -a dependency_matches=()

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
      if [[ "$INSTALL_MODE" == 'configure' ]]; then
        continue
      fi

      dependency_file="$(realpath "${dependency_matches[0]}")"
      _append_module_dependency "$map_name" "$module_file" "$dependency_file"
      _collect_module "$dependency_file" || return 1
    else
      _append_module_package "$map_name" "$module_file" "$dependency"
    fi
  done < <(_module_deps_from_string "$raw")
}

# Collect module dependencies recursively. An entry from a dependency
# function that matches a module name is installed as a module; anything else
# is treated as an apt package.
_collect_module() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local build_raw=''
  local runtime_raw=''
  local has_build=0
  local has_runtime=0
  local has_legacy=0

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

  if ! declare -F "${module}__install" > /dev/null \
    || ! declare -F "${module}__configure" > /dev/null \
    || ! declare -F "${module}__is_installed" > /dev/null \
    || ! declare -F "${module}__remove" > /dev/null \
    || ! declare -F "${module}__deconfigure" > /dev/null; then
    lib__log_error "Module '$module' does not implement the module contract."
    return 1
  fi

  declare -F "${module}__get_build_dependencies" > /dev/null && has_build=1
  declare -F "${module}__get_runtime_dependencies" > /dev/null && has_runtime=1
  declare -F "${module}__get_dependencies" > /dev/null && has_legacy=1

  if [[ "$has_build" -eq 0 && "$has_runtime" -eq 0 && "$has_legacy" -eq 0 ]]; then
    lib__log_error "Module '$module' does not declare build or runtime dependencies."
    return 1
  fi

  if [[ "$has_legacy" -eq 0 && ( "$has_build" -eq 0 || "$has_runtime" -eq 0 ) ]]; then
    lib__log_error "Module '$module' must implement both __get_build_dependencies and __get_runtime_dependencies."
    return 1
  fi

  if [[ "$has_legacy" -eq 1 && "$has_build" -eq 0 && "$has_runtime" -eq 0 ]]; then
    # Deprecated alias: unknown deps are treated as both build and runtime,
    # so old modules keep working but never lose packages automatically.
    if ! build_raw="$("${module}__get_dependencies")"; then
      lib__log_error "Failed to read dependencies of '$module'."
      return 1
    fi
    runtime_raw="$build_raw"
  else
    if [[ "$has_build" -eq 1 ]] && ! build_raw="$("${module}__get_build_dependencies")"; then
      lib__log_error "Failed to read build dependencies of '$module'."
      return 1
    fi
    if [[ "$has_runtime" -eq 1 ]] && ! runtime_raw="$("${module}__get_runtime_dependencies")"; then
      lib__log_error "Failed to read runtime dependencies of '$module'."
      return 1
    fi
  fi

  _collect_dependency_list 'build' "$module_file" "$build_raw" || return 1
  _collect_dependency_list 'runtime' "$module_file" "$runtime_raw" || return 1

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
  INSTALL_BUILD_ALL=()
  INSTALL_RUNTIME_ALL=()
  INSTALL_BUILD_FOR_RUN=()
  INSTALL_RUNTIME_FOR_RUN=()
  INSTALL_BUILD_ONLY=()
  INSTALL_BUILD_ONLY_MODULES=()
  MODULE_BUILD_PACKAGES=()
  MODULE_RUNTIME_PACKAGES=()
  MODULE_BUILD_MODULES=()
  MODULE_RUNTIME_MODULES=()
  MODULE_ROLE=()
  MODULE_ACTIVE_INSTALL=()
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

_assign_role() {
  local module_file="$1"
  local desired="$2"
  local current="${MODULE_ROLE[$module_file]:-}"

  case "$current" in
    requested|runtime)
      return 1
      ;;
    build)
      if [[ "$desired" == 'runtime' ]]; then
        MODULE_ROLE["$module_file"]='runtime'
        return 0
      fi
      return 1
      ;;
    '')
      MODULE_ROLE["$module_file"]="$desired"
      return 0
      ;;
  esac

  return 1
}

orchestrator__compute_roles() {
  local module_file
  local role
  local dependency
  local desired
  local changed=1
  local -a dependencies=()

  MODULE_ROLE=()

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    MODULE_ROLE["$module_file"]='requested'
  done

  while [[ "$changed" -eq 1 ]]; do
    changed=0

    for module_file in "${INSTALL_QUEUE[@]}"; do
      role="${MODULE_ROLE[$module_file]:-}"
      [[ -n "$role" ]] || continue

      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_BUILD_MODULES[$module_file]:-}")
      for dependency in "${dependencies[@]}"; do
        if _assign_role "$dependency" 'build'; then
          changed=1
        fi
      done

      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_RUNTIME_MODULES[$module_file]:-}")
      for dependency in "${dependencies[@]}"; do
        if [[ "$role" == 'build' ]]; then
          desired='build'
        else
          desired='runtime'
        fi
        if _assign_role "$dependency" "$desired"; then
          changed=1
        fi
      done
    done
  done

  # Every collected module should be reachable from a requested module. If
  # not, keep it and its dependencies instead of removing something unknown.
  for module_file in "${INSTALL_QUEUE[@]}"; do
    if [[ -z "${MODULE_ROLE[$module_file]:-}" ]]; then
      MODULE_ROLE["$module_file"]='runtime'
      lib__log_warn "Module '$(_module_name "$module_file")' has no dependency role; keeping it."
    fi
  done
}

# Optional module hook: return 0 when the module's program is already present
# on the system. A build-only module that the user installed by other means is
# used as is: it is not reinstalled and not scheduled for cleanup.
_module_is_present() {
  local module_file="${1:?'Do not get module file!'}"
  local module

  module="$(_module_name "$module_file")"

  declare -F "${module}__is_installed" > /dev/null || return 1
  "${module}__is_installed" > /dev/null 2>&1
}

_all_module_files() {
  find "$SOFTWARE_DIR" -type f -name '*.sh' -print | sort
}

_module_is_installed_module() {
  local module_file="${1:?'Do not get module file!'}"
  local key

  key="$(_module_key "$module_file")"
  lib__state_has_install "$key"
}

# An install attempt that failed may have left partial artifacts behind. It is
# still ours and must be removable even when __is_installed now returns true.
_module_install_attempted() {
  local module_file="${1:?'Do not get module file!'}"
  local key

  key="$(_module_key "$module_file")"
  lib__state_phase_marked "$key" install \
    || [[ -f "$(lib__state_module_dir "$key")/install.failed" ]]
}

_module_is_configured() {
  local module_file="${1:?'Do not get module file!'}"
  local key

  key="$(_module_key "$module_file")"
  lib__state_phase_marked "$key" configure
}

_installed_module_files() {
  local module_file

  while IFS= read -r module_file; do
    [[ -n "$module_file" ]] || continue
    _module_is_installed_module "$module_file" && printf '%s\n' "$module_file"
  done < <(_all_module_files)
}

_module_runtime_dependency_files() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local raw
  local dependency
  local -a matches=()

  module="$(_module_name "$module_file")"

  # shellcheck disable=SC1090
  source "$module_file" || return 1

  if ! raw="$("${module}__get_runtime_dependencies")"; then
    lib__log_error "Failed to read runtime dependencies of '$module'."
    return 1
  fi

  while IFS= read -r dependency; do
    dependency="${dependency//[[:space:]]/}"
    [[ -n "$dependency" ]] || continue
    mapfile -t matches < <(_find_module_files "$dependency")
    [[ ${#matches[@]} -eq 1 ]] || continue
    realpath "${matches[0]}"
  done < <(_module_deps_from_string "$raw")
}

_module_runtime_dependents() {
  local target="${1:?'Do not get module file!'}"
  local module_file
  local dependency

  while IFS= read -r module_file; do
    [[ "$module_file" != "$target" ]] || continue
    while IFS= read -r dependency; do
      if [[ "$dependency" == "$target" ]]; then
        printf '%s\n' "$module_file"
        break
      fi
    done < <(_module_runtime_dependency_files "$module_file")
  done < <(_installed_module_files)
}

# Run __remove for one module. Keeps configure state intact.
_orchestrator_remove_program() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local key
  local rc
  local errexit=0

  case "$-" in
    *e*) errexit=1 ;;
  esac

  module="$(_module_name "$module_file")"
  key="$(_module_key "$module_file")"

  # shellcheck disable=SC1090
  if ! source "$module_file"; then
    lib__log_error "Cannot load module '$module'."
    REMOVE_FAILED+=("$module:load")
    MANIFEST_MODULES_FAILED+=("$module:remove")
    return 1
  fi

  if ! declare -F "${module}__remove" > /dev/null; then
    lib__log_error "Module '$module' has no __remove."
    REMOVE_FAILED+=("$module:contract")
    MANIFEST_MODULES_FAILED+=("$module:remove")
    return 1
  fi

  lib__state_module_init "$key" "$module_file"
  MODULE_NAME="$module"

  set +e
  lib__state_run_action "$key" 'remove' "$module_file" "${module}__remove"
  rc=$?
  [[ "$errexit" -eq 1 ]] && set -e

  if [[ "$rc" -eq 0 ]]; then
    lib__state_clear_manual "$key"
    rm -f "$(lib__state_module_dir "$key")/install.done" \
      "$(lib__state_module_dir "$key")/install.failed" \
      "$(lib__state_module_dir "$key")/install.running"
    REMOVE_REMOVED+=("$module")
    MANIFEST_MODULES_REMOVED+=("$module")
    return 0
  fi

  if [[ "$rc" -eq 3 ]]; then
    REMOVE_KEPT+=("$module")
    MANIFEST_MODULES_KEPT+=("$module")
    return 3
  fi

  REMOVE_FAILED+=("$module:remove")
  MANIFEST_MODULES_FAILED+=("$module:remove")
  return "$rc"
}

# Run __deconfigure for one module. Keeps program and install state intact.
_orchestrator_deconfigure() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local key
  local rc
  local errexit=0

  case "$-" in
    *e*) errexit=1 ;;
  esac

  module="$(_module_name "$module_file")"
  key="$(_module_key "$module_file")"

  # shellcheck disable=SC1090
  if ! source "$module_file"; then
    lib__log_error "Cannot load module '$module'."
    REMOVE_FAILED+=("$module:load")
    MANIFEST_MODULES_FAILED+=("$module:deconfigure")
    return 1
  fi

  if ! declare -F "${module}__deconfigure" > /dev/null; then
    lib__log_error "Module '$module' has no __deconfigure."
    REMOVE_FAILED+=("$module:contract")
    MANIFEST_MODULES_FAILED+=("$module:deconfigure")
    return 1
  fi

  lib__state_module_init "$key" "$module_file"
  MODULE_NAME="$module"

  set +e
  lib__state_run_action "$key" 'deconfigure' "$module_file" "${module}__deconfigure"
  rc=$?
  [[ "$errexit" -eq 1 ]] && set -e

  if [[ "$rc" -eq 0 ]]; then
    rm -f "$(lib__state_module_dir "$key")/configure.done" \
      "$(lib__state_module_dir "$key")/configure.failed" \
      "$(lib__state_module_dir "$key")/configure.running"
    REMOVE_DECONFIGURED+=("$module")
    return 0
  fi

  if [[ "$rc" -eq 3 ]]; then
    REMOVE_KEPT+=("$module:deconfigure")
    MANIFEST_MODULES_KEPT+=("$module:deconfigure")
    return 3
  fi

  REMOVE_FAILED+=("$module:deconfigure")
  MANIFEST_MODULES_FAILED+=("$module:deconfigure")
  return "$rc"
}

# Remove managed dependency modules that no longer have an installed
# manual/external dependent. Configurations are intentionally kept: only
# __remove runs here.
orchestrator__autoremove_modules() {
  local module_file
  local key
  local rc
  local changed=1
  local failed=0
  local -A needed=()
  local -a queue=()

  while IFS= read -r module_file; do
    key="$(_module_key "$module_file")"
    if lib__state_is_manual "$key" || lib__state_is_external "$key"; then
      needed["$module_file"]=1
      queue+=("$module_file")
    fi
  done < <(_installed_module_files)

  while [[ ${#queue[@]} -gt 0 ]]; do
    module_file="${queue[0]}"
    queue=("${queue[@]:1}")
    while IFS= read -r dependency; do
      if [[ -z "${needed[$dependency]:-}" ]]; then
        needed["$dependency"]=1
        queue+=("$dependency")
      fi
    done < <(_module_runtime_dependency_files "$module_file")
  done

  while [[ "$changed" -eq 1 ]]; do
    changed=0

    while IFS= read -r module_file; do
      [[ -z "${needed[$module_file]:-}" ]] || continue

      key="$(_module_key "$module_file")"
      lib__state_is_manual "$key" && continue
      lib__state_is_external "$key" && continue
      _module_is_installed_module "$module_file" || continue

      if [[ -n "$(_module_runtime_dependents "$module_file")" ]]; then
        continue
      fi

      set +e
      _orchestrator_remove_program "$module_file"
      rc=$?
      set -e

      if [[ "$rc" -eq 0 ]]; then
        changed=1
      elif [[ "$rc" -ne 3 ]]; then
        failed=1
      fi
    done < <(_installed_module_files)
  done

  return "$failed"
}

orchestrator__remove_plan() {
  local module_file
  local dependent_file
  local module
  local key
  local -a dependents=()
  local -A target_set=()

  queue_modules "$@" || return 1
  lib__state_load

  REMOVE_MODULES=()
  REMOVE_NAMES=()
  REMOVE_KEYS=()
  REMOVE_BLOCKED=()
  REMOVE_SKIPPED=()
  REMOVE_REMOVED=()
  REMOVE_DECONFIGURED=()
  REMOVE_KEPT=()
  REMOVE_FAILED=()

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    target_set["$module_file"]=1
  done

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    module="$(_module_name "$module_file")"
    key="$(_module_key "$module_file")"

    # shellcheck disable=SC1090
    if ! source "$module_file"; then
      lib__log_error "Cannot load module '$module'."
      return 1
    fi

    REMOVE_MODULES+=("$module_file")
    REMOVE_NAMES+=("$module")
    REMOVE_KEYS+=("$key")

    if [[ "$REMOVE_PROGRAM" -eq 1 ]]; then
      if ! lib__state_has_install "$key"; then
        if _module_install_attempted "$module_file"; then
          : # partial install from a failed run; allow __remove to clean it
        elif _module_is_present "$module_file"; then
          REMOVE_BLOCKED+=("$module: installed outside the installer; use reinstall to adopt it")
        else
          REMOVE_SKIPPED+=("$module: not installed")
        fi
      elif lib__state_is_external "$key"; then
        REMOVE_BLOCKED+=("$module: installed outside the installer; use reinstall to adopt it")
      else
        dependents=()
        while IFS= read -r dependent_file; do
          [[ -z "${target_set[$dependent_file]:-}" ]] || continue
          dependents+=("$(_module_name "$dependent_file")")
        done < <(_module_runtime_dependents "$module_file")

        if [[ ${#dependents[@]} -gt 0 ]]; then
          REMOVE_BLOCKED+=("$module: needed by ${dependents[*]}; remove the dependent module first")
        fi
      fi
    fi

    if [[ "$REMOVE_CONFIG" -eq 1 ]] && ! _module_is_configured "$module_file"; then
      REMOVE_SKIPPED+=("$module: not configured")
    fi
  done
}

orchestrator__print_remove_plan() {
  local item

  printf '%-9s %s%s%s (uid %s)\n' 'User' "$UI_BOLD" "$USER" "$UI_RESET" "$UID"
  printf '%-9s %s\n' 'Home' "$HOME"
  printf '%-9s %s\n' 'State' "$(lib__ui_tilde_path "$STATE_ROOT")"

  if [[ "$REMOVE_PROGRAM" -eq 1 && "$REMOVE_CONFIG" -eq 1 ]]; then
    printf '%-9s %sremove program and configuration%s\n' 'Action' "$UI_BOLD$UI_YELLOW" "$UI_RESET"
  elif [[ "$REMOVE_PROGRAM" -eq 1 ]]; then
    printf '%-9s %sremove program, keep configuration%s\n' 'Action' "$UI_BOLD$UI_YELLOW" "$UI_RESET"
  else
    printf '%-9s %sremove configuration, keep program%s\n' 'Action' "$UI_BOLD$UI_YELLOW" "$UI_RESET"
  fi

  if [[ "$INSTALL_DRY_RUN" -eq 1 ]]; then
    printf '%-9s %syes, nothing will be changed%s\n' 'Dry run' "$UI_YELLOW" "$UI_RESET"
  fi

  printf '\nModules: %s selected\n' "${#REMOVE_MODULES[@]}"

  for item in "${REMOVE_MODULES[@]}"; do
    printf '  %s%s %s%s\n' "$UI_YELLOW" "$UI_ARROW" "$(_module_display_name "$item")" "$UI_RESET"
  done

  for item in "${REMOVE_BLOCKED[@]}"; do
    printf '  %s%s%s %s\n' "$UI_RED" "$UI_FAIL" "$UI_RESET" "$item"
  done

  for item in "${REMOVE_SKIPPED[@]}"; do
    printf '  %s%s %s%s\n' "$UI_DIM" "$UI_SKIP" "$item" "$UI_RESET"
  done

  if [[ ${#REMOVE_BLOCKED[@]} -gt 0 ]]; then
    printf '\n  %sNothing will be changed until the blockers are resolved.%s\n' "$UI_YELLOW" "$UI_RESET"
  fi

  printf '\n'
}

orchestrator__remove_run() {
  local index
  local module_file
  local module
  local key
  local rc
  local program_rc=0
  local program_requested
  local config_requested
  local failed=0
  local removed_any=0

  if [[ ${#REMOVE_BLOCKED[@]} -gt 0 ]]; then
    local item
    for item in "${REMOVE_BLOCKED[@]}"; do
      lib__log_error "$item"
    done
    return 1
  fi

  lib__state_init
  lib__state_lock || return 1
  lib__manifest_begin || {
    lib__state_unlock
    return 1
  }

  MANIFEST_KEEP_BUILD_DEPS="$INSTALL_KEEP_BUILD_DEPS"
  MANIFEST_FORCE_CLEAN="$INSTALL_FORCE_CLEAN"

  for module_file in "${REMOVE_MODULES[@]}"; do
    MANIFEST_MODULES_REQUESTED+=("$(_module_name "$module_file")")
  done

  for index in "${!REMOVE_MODULES[@]}"; do
    module_file="${REMOVE_MODULES[$index]}"
    module="${REMOVE_NAMES[$index]}"
    key="${REMOVE_KEYS[$index]}"
    program_rc=0
    program_requested=0
    config_requested=0

    if [[ "$REMOVE_PROGRAM" -eq 1 ]] \
      && { lib__state_has_install "$key" || _module_install_attempted "$module_file"; }; then
      if lib__state_is_external "$key"; then
        lib__log_error "$module: installed outside the installer; keeping it."
        REMOVE_FAILED+=("$module:external")
        MANIFEST_MODULES_FAILED+=("$module:remove")
        failed=1
        continue
      fi
      program_requested=1
    fi

    if [[ "$REMOVE_CONFIG" -eq 1 ]] && _module_is_configured "$module_file"; then
      config_requested=1
    fi

    if [[ "$program_requested" -eq 0 && "$config_requested" -eq 0 ]]; then
      REMOVE_SKIPPED+=("$module: nothing to do")
      continue
    fi

    if [[ "$program_requested" -eq 1 ]]; then
      set +e
      _orchestrator_remove_program "$module_file"
      program_rc=$?
      set -e

      if [[ "$program_rc" -eq 0 ]]; then
        removed_any=1
      elif [[ "$program_rc" -eq 3 ]]; then
        # The program was kept (for example, an apt reverse dependency).
        # Do not deconfigure it in the same run.
        failed=1
        continue
      else
        failed=1
        continue
      fi
    fi

    if [[ "$config_requested" -eq 1 ]]; then
      set +e
      _orchestrator_deconfigure "$module_file"
      rc=$?
      set -e
      if [[ "$rc" -ne 0 ]]; then
        failed=1
      fi
    fi
  done

  if [[ "$removed_any" -eq 1 && "$failed" -eq 0 ]]; then
    orchestrator__autoremove_modules || failed=1
  fi

  for module in "${REMOVE_REMOVED[@]}"; do
    lib__log_success "Removed program: $module"
  done
  for module in "${REMOVE_DECONFIGURED[@]}"; do
    lib__log_success "Removed configuration: $module"
  done
  for module in "${REMOVE_KEPT[@]}"; do
    lib__log_warn "Kept: $module"
  done
  for module in "${REMOVE_FAILED[@]}"; do
    lib__log_error "Failed: $module"
  done

  if [[ "$failed" -eq 0 ]]; then
    MANIFEST_STATUS='success'
    lib__state_unlock
    if [[ "$REMOVE_PROGRAM" -eq 0 ]]; then
      lib__log_success 'Selected configurations were removed.'
    elif [[ "$REMOVE_CONFIG" -eq 1 ]]; then
      lib__log_success 'Selected programs and configurations were removed.'
    else
      lib__log_success 'Selected programs were removed.'
    fi
    return 0
  fi

  MANIFEST_STATUS='failed'
  lib__state_unlock
  if [[ "$REMOVE_PROGRAM" -eq 0 ]]; then
    lib__log_error 'Deconfiguration finished with errors.'
  else
    lib__log_error 'Removal finished with errors.'
  fi
  return 1
}

# A build-only module is needed only when some requested/runtime module that
# actually installs in this run depends on it. Without this, a second run of
# an already-installed program would resurrect its build dependencies just
# because the build-only module state was reset after the previous cleanup.
orchestrator__compute_active_install_set() {
  local module_file
  local key
  local role
  local dependency
  local changed=1
  local -a dependencies=()

  MODULE_ACTIVE_INSTALL=()

  for module_file in "${INSTALL_QUEUE[@]}"; do
    role="${MODULE_ROLE[$module_file]:-runtime}"
    [[ "$role" == 'build' ]] && continue

    key="$(_module_key "$module_file")"
    if orchestrator__phase_enabled "$module_file" install \
      && _module_has_pending_install "$key" "$module_file"; then
      MODULE_ACTIVE_INSTALL["$module_file"]=1
    fi
  done

  while [[ "$changed" -eq 1 ]]; do
    changed=0

    for module_file in "${INSTALL_QUEUE[@]}"; do
      [[ -n "${MODULE_ACTIVE_INSTALL[$module_file]:-}" ]] || continue
      role="${MODULE_ROLE[$module_file]:-runtime}"

      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_BUILD_MODULES[$module_file]:-}")
      for dependency in "${dependencies[@]}"; do
        [[ -z "${MODULE_ACTIVE_INSTALL[$dependency]:-}" ]] || continue

        if ! orchestrator__phase_enabled "$dependency" install; then
          continue
        fi

        # An already completed build-only module, or one that is present
        # outside the installer, is used as is. It must not be reinstalled
        # and later listed for cleanup.
        key="$(_module_key "$dependency")"
        if orchestrator__should_skip "$key" install "$dependency"; then
          continue
        fi

        if _module_is_present "$dependency"; then
          continue
        fi

        MODULE_ACTIVE_INSTALL["$dependency"]=1
        changed=1
      done

      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_RUNTIME_MODULES[$module_file]:-}")
      for dependency in "${dependencies[@]}"; do
        if [[ "$role" != 'build' ]]; then
          # A runtime dependency that is already installed does not need its
          # own build dependencies. Only an installing runtime module does.
          key="$(_module_key "$dependency")"
          if ! orchestrator__phase_enabled "$dependency" install \
            || ! _module_has_pending_install "$key" "$dependency"; then
            continue
          fi
        fi

        if [[ -z "${MODULE_ACTIVE_INSTALL[$dependency]:-}" ]]; then
          MODULE_ACTIVE_INSTALL["$dependency"]=1
          changed=1
        fi
      done
    done
  done
}

orchestrator__compute_all_dependency_sets() {
  local module_file
  local role
  local -a dependencies=()

  INSTALL_BUILD_ALL=()
  INSTALL_RUNTIME_ALL=()

  for module_file in "${INSTALL_QUEUE[@]}"; do
    role="${MODULE_ROLE[$module_file]:-runtime}"

    mapfile -t dependencies < <(_module_deps_from_string "${MODULE_BUILD_PACKAGES[$module_file]:-}")
    _array_add_unique INSTALL_BUILD_ALL "${dependencies[@]}"

    mapfile -t dependencies < <(_module_deps_from_string "${MODULE_RUNTIME_PACKAGES[$module_file]:-}")
    if [[ "$role" == 'build' ]]; then
      _array_add_unique INSTALL_BUILD_ALL "${dependencies[@]}"
    else
      _array_add_unique INSTALL_RUNTIME_ALL "${dependencies[@]}"
    fi
  done
}

orchestrator__filter_dependency_sets() {
  local module_file
  local key
  local role
  local -a dependencies=()

  INSTALL_BUILD_FOR_RUN=()
  INSTALL_RUNTIME_FOR_RUN=()
  INSTALL_BUILD_ONLY_MODULES=()

  if ! orchestrator__deps_enabled; then
    return 0
  fi

  for module_file in "${INSTALL_QUEUE[@]}"; do
    role="${MODULE_ROLE[$module_file]:-runtime}"
    key="$(_module_key "$module_file")"

    if [[ "$role" != 'build' ]]; then
      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_RUNTIME_PACKAGES[$module_file]:-}")
      _array_add_unique INSTALL_RUNTIME_FOR_RUN "${dependencies[@]}"
    fi

    if [[ -n "${MODULE_ACTIVE_INSTALL[$module_file]:-}" ]] \
      && orchestrator__phase_enabled "$module_file" install \
      && _module_has_pending_install "$key" "$module_file"; then
      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_BUILD_PACKAGES[$module_file]:-}")
      _array_add_unique INSTALL_BUILD_FOR_RUN "${dependencies[@]}"
    fi

    if [[ "$role" == 'build' && -n "${MODULE_ACTIVE_INSTALL[$module_file]:-}" ]]; then
      # Runtime libraries of a build-only tool are needed while it runs,
      # even if its install phase was completed in an earlier run.
      mapfile -t dependencies < <(_module_deps_from_string "${MODULE_RUNTIME_PACKAGES[$module_file]:-}")
      _array_add_unique INSTALL_BUILD_FOR_RUN "${dependencies[@]}"
      INSTALL_BUILD_ONLY_MODULES+=("$module_file")
    fi
  done
}

orchestrator__prepare_dependency_sets() {
  lib__cleanup_pending_load
  orchestrator__compute_roles
  orchestrator__compute_active_install_set
  orchestrator__compute_all_dependency_sets
  orchestrator__filter_dependency_sets

  if [[ "$INSTALL_DRY_RUN" -eq 1 && "$INSTALL_KEEP_BUILD_DEPS" -eq 0 ]]; then
    orchestrator__apt_snapshot_before
    orchestrator__compute_build_only
  fi
}

orchestrator__deps_enabled() {
  [[ "$INSTALL_MODE" != 'configure' ]]
}

# Build-only modules that are not needed by an installing module are left
# alone. They are not part of this run's plan and are not reinstalled.
orchestrator__module_needed() {
  local module_file="${1:?'Do not get module file!'}"

  if [[ "${MODULE_ROLE[$module_file]:-runtime}" == 'build' ]] \
    && [[ -z "${MODULE_ACTIVE_INSTALL[$module_file]:-}" ]]; then
    return 1
  fi

  return 0
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
  if [[ "$INSTALL_FORCE" -eq 1 ]]; then
    printf 'reinstall (force deps + install + configure)\n'
    return 0
  fi

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

  if ! orchestrator__module_needed "$module_file"; then
    printf 'skipped'
  elif ! orchestrator__phase_enabled "$module_file" "$phase"; then
    printf 'skipped'
  elif [[ "$INSTALL_FORCE" -eq 1 ]]; then
    printf 'pending'
  elif [[ "$phase" == 'install' ]] && lib__state_is_external "$key"; then
    printf 'done'
  elif lib__state_phase_done "$key" "$phase" "$module_file"; then
    printf 'done'
  elif [[ "$phase" == 'install' ]] \
    && ! lib__state_phase_marked "$key" install \
    && _module_is_present "$module_file"; then
    printf 'done'
  else
    printf 'pending'
  fi
}

_module_has_pending_install() {
  local key="${1:?'Do not get module key!'}"
  local module_file="${2:?'Do not get module file!'}"

  orchestrator__phase_enabled "$module_file" install || return 1
  [[ "$(orchestrator__phase_status "$key" install "$module_file")" == 'pending' ]] || return 1

  # A program that is present but not recorded yet will be marked external,
  # not installed. Do not pull its build dependencies for nothing.
  if ! lib__state_phase_marked "$key" install && _module_is_present "$module_file"; then
    return 1
  fi

  return 0
}

_module_has_pending() {
  local key="${1:?'Do not get module key!'}"
  local module_file="${2:?'Do not get module file!'}"

  if _module_has_pending_install "$key" "$module_file"; then
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
      printf '%s%s%s' "$UI_BOLD$UI_GREEN" "$UI_DONE" "$UI_RESET"
      ;;
    pending)
      printf '%s%s%s' "$UI_BOLD$UI_YELLOW" "$UI_TODO" "$UI_RESET"
      ;;
    skipped)
      printf '%s%s%s' "$UI_DIM" "$UI_SKIP" "$UI_RESET"
      ;;
    *)
      printf '%s%s%s' "$UI_BOLD$UI_RED" "$UI_FAIL" "$UI_RESET"
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
      printf '\n  %s%s%s\n' "$UI_BOLD$UI_YELLOW" "$rel_dir" "$UI_RESET"
      printf '    %s%-*s  %-8s%s%s\n' "$UI_DIM" "$label_width" '' 'install' 'configure' "$UI_RESET"
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

    if [[ -z "${REQUESTED_SET[$module_file]:-}" ]]; then
      printf ' %s(dependency)%s' "$UI_DIM" "$UI_RESET"
    fi

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
  local module_label
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
    printf '%-9s %syes, install and configure run again%s\n' 'Reinstall' "$UI_YELLOW" "$UI_RESET"
  fi

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 ]]; then
    printf '%-9s %syes, build dependencies and build-only modules are kept%s\n' 'Keep deps' "$UI_YELLOW" "$UI_RESET"
  fi

  if [[ "$INSTALL_FORCE_CLEAN" -eq 1 ]]; then
    printf '%-9s %syes, cleanup runs even if modules fail%s\n' 'Force clean' "$UI_YELLOW" "$UI_RESET"
  fi

  if [[ "$INSTALL_DRY_RUN" -eq 1 ]]; then
    printf '%-9s %syes, nothing will be changed%s\n' 'Dry run' "$UI_YELLOW" "$UI_RESET"
  fi

  local not_needed_count=0

  for index in "${!INSTALL_QUEUE[@]}"; do
    key="${INSTALL_KEYS[$index]}"
    module_file="${INSTALL_QUEUE[$index]}"

    if ! orchestrator__module_needed "$module_file"; then
      not_needed_count=$((not_needed_count + 1))
      continue
    fi

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
  elif ((not_needed_count > 0)); then
    printf ' · %sall needed done%s' "$UI_GREEN" "$UI_RESET"
  else
    printf ' · %sall done%s' "$UI_GREEN" "$UI_RESET"
  fi
  if ((not_needed_count > 0)); then
    printf ' · %s%s not needed%s' "$UI_DIM" "$not_needed_count" "$UI_RESET"
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

  if (( ${#INSTALL_BUILD_ONLY_MODULES[@]} > 0 )); then
    if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 ]]; then
      printf '\n  %sBuild-only modules kept (--keep-build-deps) (%s)%s\n' \
        "$UI_BOLD$UI_CYAN" "${#INSTALL_BUILD_ONLY_MODULES[@]}" "$UI_RESET"
    else
      printf '\n  %sBuild-only modules for cleanup after a successful run (%s)%s\n' \
        "$UI_BOLD$UI_CYAN" "${#INSTALL_BUILD_ONLY_MODULES[@]}" "$UI_RESET"
    fi

    for module_file in "${INSTALL_BUILD_ONLY_MODULES[@]}"; do
      module_label="$(_module_display_name "$module_file")"
      printf '    %s%s %s%s\n' "$UI_DIM" "$UI_ARROW" "$module_label" "$UI_RESET"
    done
  fi

  if (( ${#CLEANUP_PENDING_PACKAGES[@]} > 0 || ${#CLEANUP_PENDING_MODULES[@]} > 0 )); then
    printf '\n  %sPending cleanup from a previous run:%s %s package(s), %s module(s)\n' \
      "$UI_BOLD$UI_YELLOW" "$UI_RESET" \
      "${#CLEANUP_PENDING_PACKAGES[@]}" "${#CLEANUP_PENDING_MODULES[@]}"
  fi

  printf '\n'
  if orchestrator__deps_enabled; then
    if ! lib__apt_lists_present \
      && [[ ${#INSTALL_BUILD_FOR_RUN[@]} -gt 0 || ${#INSTALL_RUNTIME_FOR_RUN[@]} -gt 0 ]]; then
      lib__log_warn 'apt package lists are empty; dependency versions are unknown until apt-get update runs.'
    fi

    lib__apt_print_dependencies 'Build dependencies' "$INSTALL_VERBOSE" "${INSTALL_BUILD_FOR_RUN[@]}"
    lib__apt_print_dependencies 'Runtime dependencies' "$INSTALL_VERBOSE" "${INSTALL_RUNTIME_FOR_RUN[@]}"

    if [[ "$INSTALL_DRY_RUN" -eq 1 && ${#INSTALL_BUILD_ONLY[@]} -gt 0 ]]; then
      printf '  %sBuild-only packages for autoremove:%s %s\n' \
        "$UI_BOLD" "$UI_RESET" "${#INSTALL_BUILD_ONLY[@]}"
    fi
  else
    printf '  %sDependencies:%s %sskipped (configure-only)%s\n' \
      "$UI_BOLD" "$UI_RESET" "$UI_DIM" "$UI_RESET"
  fi
  printf '\n'
}

orchestrator__should_skip() {
  local key="${1:?'Do not get module key!'}"
  local phase="${2:?'Do not get phase!'}"
  local module_file="${3:?'Do not get module file!'}"

  if [[ "$INSTALL_FORCE" -eq 1 ]]; then
    return 1
  fi

  if [[ "$phase" == 'install' ]] && lib__state_is_external "$key"; then
    return 0
  fi

  lib__state_phase_done "$key" "$phase" "$module_file"
}

orchestrator__apt_snapshot_before() {
  local package

  mapfile -t APT_MANUAL_BEFORE < <(lib__apt_show_manual)
  mapfile -t APT_INSTALLED_BEFORE < <(lib__apt_installed_list)

  APT_MANUAL_BEFORE_SET=()
  for package in "${APT_MANUAL_BEFORE[@]}"; do
    APT_MANUAL_BEFORE_SET["$package"]=1
  done

  if [[ -n "${MANIFEST_DIR:-}" ]]; then
    printf '%s\n' "${APT_INSTALLED_BEFORE[@]}" > "$MANIFEST_DIR/installed_before.txt"
  fi
}

orchestrator__apt_snapshot_after() {
  local before_file
  local after_file

  mapfile -t APT_INSTALLED_AFTER < <(lib__apt_installed_list)

  if [[ -z "${MANIFEST_DIR:-}" ]]; then
    return 0
  fi

  before_file="$MANIFEST_DIR/installed_before.txt"
  after_file="$MANIFEST_DIR/installed_after.txt"
  printf '%s\n' "${APT_INSTALLED_AFTER[@]}" > "$after_file"

  mapfile -t APT_INSTALLED_BY_US < <(
    comm -13 \
      <(LC_ALL=C sort -u "$before_file") \
      <(LC_ALL=C sort -u "$after_file")
  )
}

orchestrator__apt_snapshot_cleanup_before() {
  mapfile -t APT_INSTALLED_BEFORE_CLEANUP < <(lib__apt_installed_list)

  if [[ -n "${MANIFEST_DIR:-}" ]]; then
    printf '%s\n' "${APT_INSTALLED_BEFORE_CLEANUP[@]}" \
      > "$MANIFEST_DIR/installed_before_cleanup.txt"
  fi
}

orchestrator__apt_snapshot_cleanup_after() {
  local before_file
  local after_file

  mapfile -t APT_INSTALLED_AFTER_CLEANUP < <(lib__apt_installed_list)

  if [[ -z "${MANIFEST_DIR:-}" ]]; then
    return 0
  fi

  before_file="$MANIFEST_DIR/installed_before_cleanup.txt"
  after_file="$MANIFEST_DIR/installed_after_cleanup.txt"
  printf '%s\n' "${APT_INSTALLED_AFTER_CLEANUP[@]}" > "$after_file"

  mapfile -t APT_AUTOREMOVE_REMOVED < <(
    comm -23 \
      <(LC_ALL=C sort -u "$before_file") \
      <(LC_ALL=C sort -u "$after_file")
  )
}

orchestrator__compute_build_only() {
  local package
  local -A runtime_set=()

  INSTALL_BUILD_ONLY=()

  for package in "${INSTALL_RUNTIME_FOR_RUN[@]}"; do
    runtime_set["$package"]=1
  done

  for package in "${INSTALL_BUILD_FOR_RUN[@]}"; do
    [[ -n "${runtime_set[$package]:-}" ]] && continue
    [[ -n "${APT_MANUAL_BEFORE_SET[$package]:-}" ]] && continue
    INSTALL_BUILD_ONLY+=("$package")
  done

  # Pending packages were installed by an earlier run. They stay cleanup
  # candidates even if apt now reports them as manual, which is exactly the
  # crash-between-install-and-mark-auto recovery path.
  for package in "${CLEANUP_PENDING_PACKAGES[@]}"; do
    [[ -n "${runtime_set[$package]:-}" ]] && continue
    INSTALL_BUILD_ONLY+=("$package")
  done

  _array_dedupe INSTALL_BUILD_ONLY
}

orchestrator__cleanup_pending_prepare() {
  local module_file
  local relative

  for module_file in "${INSTALL_BUILD_ONLY[@]}"; do
    lib__cleanup_pending_track_package "$module_file"
  done

  for module_file in "${INSTALL_BUILD_ONLY_MODULES[@]}"; do
    relative="${module_file#"$SOFTWARE_DIR"/}"
    lib__cleanup_pending_track_module "$relative"
  done

  lib__cleanup_pending_write
}

orchestrator__has_pending_work() {
  local index
  local key
  local module_file
  local package
  local lists_present=0

  if [[ "$INSTALL_MODE" != 'configure' ]]; then
    for module_file in "${INSTALL_REQUESTED[@]}"; do
      key="$(_module_key "$module_file")"
      if ! lib__state_is_manual "$key"; then
        return 0
      fi
    done
  fi

  if lib__apt_lists_present; then
    lists_present=1
  fi

  if orchestrator__deps_enabled; then
    for package in "${INSTALL_RUNTIME_FOR_RUN[@]}"; do
      lib__apt_is_installed "$package" && continue
      if [[ "$lists_present" -eq 0 ]] || lib__apt_available "$package"; then
        return 0
      fi
    done

    for package in "${INSTALL_BUILD_FOR_RUN[@]}"; do
      lib__apt_is_installed "$package" && continue
      if [[ "$lists_present" -eq 0 ]] || lib__apt_available "$package"; then
        return 0
      fi
    done
  fi

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 0 ]]; then
    if [[ ${#CLEANUP_PENDING_PACKAGES[@]} -gt 0 || ${#CLEANUP_PENDING_MODULES[@]} -gt 0 ]]; then
      return 0
    fi

    if [[ ${#INSTALL_BUILD_ONLY_MODULES[@]} -gt 0 ]]; then
      return 0
    fi
  fi

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    key="${INSTALL_KEYS[$index]}"

    if ! orchestrator__module_needed "$module_file"; then
      continue
    fi

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

  case "$INSTALL_MODE" in
    install)
      flags+=(install --no-configure)
      ;;
    configure)
      flags+=(configure)
      ;;
    *)
      if [[ "$INSTALL_FORCE" -eq 1 ]]; then
        flags+=(reinstall)
      else
        flags+=(install)
      fi
      ;;
  esac

  flags+=(-y)

  if [[ "$INSTALL_KEEP_GOING" -eq 1 ]]; then
    flags+=(--keep-going)
  fi

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 ]]; then
    flags+=(--keep-build-deps)
  fi

  if [[ "$INSTALL_FORCE_CLEAN" -eq 1 ]]; then
    flags+=(--force-clean)
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

orchestrator__module_blocked() {
  local module_file="${1:?'Do not get module file!'}"
  local dependency
  local -a dependencies=()

  mapfile -t dependencies < <(
    {
      printf '%s\n' "${MODULE_BUILD_MODULES[$module_file]:-}"
      printf '%s\n' "${MODULE_RUNTIME_MODULES[$module_file]:-}"
    } | awk 'NF && !seen[$0]++'
  )

  for dependency in "${dependencies[@]}"; do
    if [[ -n "${_MODULE_FAILED[$dependency]:-}" || -n "${_MODULE_SKIPPED[$dependency]:-}" ]]; then
      return 0
    fi
  done

  return 1
}

orchestrator__remove_module() {
  local module_file="${1:?'Do not get module file!'}"
  local module
  local key
  local rc
  local errexit=0

  case "$-" in
    *e*) errexit=1 ;;
  esac

  module="$(_module_name "$module_file")"
  key="$(_module_key "$module_file")"

  if lib__state_is_external "$key" || lib__state_is_manual "$key"; then
    INSTALL_KEPT_BUILD_ONLY+=("$module")
    MANIFEST_MODULES_KEPT+=("$module")
    return 0
  fi

  # shellcheck disable=SC1090
  if ! source "$module_file"; then
    lib__log_warn "Cannot load build-only module '$module'; keeping it."
    INSTALL_KEPT_BUILD_ONLY+=("$module")
    MANIFEST_MODULES_KEPT+=("$module")
    return 0
  fi

  lib__state_module_init "$key" "$module_file"
  MODULE_NAME="$module"

  # Call the action outside any condition context and capture its status.
  # A condition such as `if ! action` disables errexit inside it, which would
  # let a module continue after a failed build command.
  set +e
  lib__state_run_action "$key" 'remove' "$module_file" "${module}__remove"
  rc=$?
  [[ "$errexit" -eq 1 ]] && set -e

  if [[ "$rc" -eq 0 ]]; then
    INSTALL_REMOVED+=("$module")
    MANIFEST_MODULES_REMOVED+=("$module")
    lib__state_reset "$key"
    return 0
  fi

  if [[ "$rc" -eq 3 ]]; then
    INSTALL_KEPT_BUILD_ONLY+=("$module")
    MANIFEST_MODULES_KEPT+=("$module")
    return 0
  fi

  lib__log_warn "Failed to remove build-only module '$module'; keeping it."
  INSTALL_KEPT_BUILD_ONLY+=("$module")
  MANIFEST_MODULES_KEPT+=("$module")
  return 1
}

orchestrator__warn_unexpected_autoremove() {
  local package
  local -A allowed=()
  local -a unexpected=()

  for package in "${INSTALL_BUILD_ONLY[@]}"; do
    allowed["$package"]=1
  done
  for package in "${APT_INSTALLED_BY_US[@]}"; do
    allowed["$package"]=1
  done
  for package in "${CLEANUP_PENDING_PACKAGES[@]}"; do
    allowed["$package"]=1
  done

  for package in "${APT_AUTOREMOVE_PREVIEW[@]}"; do
    if [[ -z "${allowed[$package]:-}" ]]; then
      unexpected+=("$package")
    fi
  done

  if [[ ${#unexpected[@]} -gt 0 ]]; then
    lib__log_warn "autoremove will also remove packages not installed by this run: ${unexpected[*]}"
  fi
}

orchestrator__cleanup() {
  local module_file
  local relative
  local index
  local cleanup_failed=0
  local -a module_files=()

  for module_file in "${INSTALL_BUILD_ONLY_MODULES[@]}"; do
    module_files+=("$module_file")
  done

  for relative in "${CLEANUP_PENDING_MODULES[@]}"; do
    module_file="$SOFTWARE_DIR/$relative"
    if [[ -f "$module_file" ]]; then
      module_files+=("$module_file")
    else
      lib__log_warn "Pending build-only module '$relative' no longer exists; skipping."
    fi
  done

  _array_dedupe module_files

  # Remove dependants before their dependencies.
  for ((index = ${#module_files[@]} - 1; index >= 0; index--)); do
    module_file="${module_files[$index]}"

    if [[ -n "${REQUESTED_SET[$module_file]:-}" ]]; then
      continue
    fi

    case "${MODULE_ROLE[$module_file]:-build}" in
      requested|runtime)
        continue
        ;;
    esac

    if ! orchestrator__remove_module "$module_file"; then
      cleanup_failed=1
    fi
  done

  if [[ "$cleanup_failed" -ne 0 ]]; then
    lib__log_warn 'Skipping autoremove because module removal failed; build dependencies are kept for a retry.'
  elif [[ ${#INSTALL_BUILD_ONLY[@]} -gt 0 || ${#INSTALL_REMOVED[@]} -gt 0 ]]; then
    orchestrator__apt_snapshot_cleanup_before

    mapfile -t APT_AUTOREMOVE_PREVIEW < <(lib__apt_autoremove_preview)
    MANIFEST_AUTOREMOVE_PREVIEW=("${APT_AUTOREMOVE_PREVIEW[@]}")
    orchestrator__warn_unexpected_autoremove

    if lib__apt_autoremove; then
      MANIFEST_AUTOREMOVE_RAN=1
      orchestrator__apt_snapshot_cleanup_after
      MANIFEST_AUTOREMOVE_REMOVED=("${APT_AUTOREMOVE_REMOVED[@]}")
    else
      lib__log_error 'Failed to clean build dependencies.'
      cleanup_failed=1
    fi
  fi

  if [[ "$cleanup_failed" -eq 0 ]]; then
    lib__cleanup_pending_clear
    MANIFEST_PENDING_CLEANUP_PROCESSED=1
  fi

  return "$cleanup_failed"
}

orchestrator__run() {
  local index
  local module_file
  local key
  local module
  local module_ok
  local failed=0
  local cleanup_failed=0
  local phase_rc=0
  local -a failed_entries=()
  local -a dependency_packages=()

  lib__state_init
  lib__state_lock || return 1
  lib__manifest_begin || {
    lib__state_unlock
    return 1
  }

  MANIFEST_KEEP_BUILD_DEPS="$INSTALL_KEEP_BUILD_DEPS"
  MANIFEST_FORCE_CLEAN="$INSTALL_FORCE_CLEAN"

  for module_file in "${INSTALL_REQUESTED[@]}"; do
    MANIFEST_MODULES_REQUESTED+=("$(_module_name "$module_file")")
  done

  MANIFEST_BUILD_ALL=("${INSTALL_BUILD_ALL[@]}")
  MANIFEST_RUNTIME_ALL=("${INSTALL_RUNTIME_ALL[@]}")

  lib__cleanup_pending_load

  # An explicit install/reinstall request marks the module manual, like
  # `apt install` marks a package manual. Dependencies do not get this marker.
  for module_file in "${INSTALL_REQUESTED[@]}"; do
    if orchestrator__phase_enabled "$module_file" install; then
      lib__state_mark_manual "$(_module_key "$module_file")"
    fi
  done

  # --keep-build-deps keeps build-only modules as manual dependencies.
  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 1 ]]; then
    for module_file in "${INSTALL_BUILD_ONLY_MODULES[@]}"; do
      lib__state_mark_manual "$(_module_key "$module_file")"
    done
  fi

  orchestrator__apt_snapshot_before
  MANIFEST_MANUAL_BEFORE=("${APT_MANUAL_BEFORE[@]}")

  # Compute and persist cleanup candidates before apt changes anything. This
  # closes the crash window between the batch install and apt-mark auto: a
  # package that is manual afterwards is still listed in cleanup.pending.
  orchestrator__compute_build_only
  MANIFEST_BUILD_ONLY=("${INSTALL_BUILD_ONLY[@]}")

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 0 ]]; then
    orchestrator__cleanup_pending_prepare
  fi

  if orchestrator__deps_enabled; then
    _array_add_unique dependency_packages "${INSTALL_BUILD_FOR_RUN[@]}"
    _array_add_unique dependency_packages "${INSTALL_RUNTIME_FOR_RUN[@]}"

    if [[ ${#dependency_packages[@]} -gt 0 ]]; then
      if ! lib__apt_install_batch "${dependency_packages[@]}" </dev/null; then
        MANIFEST_STATUS='failed'
        MANIFEST_MODULES_FAILED+=('dependencies:apt')
        INSTALL_FAILED+=('dependencies:apt')
        lib__log_error 'Dependency installation failed.'
        orchestrator__apt_snapshot_after
        MANIFEST_INSTALLED_BY_US=("${APT_INSTALLED_BY_US[@]}")
        lib__state_unlock
        orchestrator__print_resume 'dependencies:apt'
        return 1
      fi
    fi
  fi

  # Runtime dependencies must be manual even if they were already present as
  # auto. This is the protection against a later autoremove.
  if orchestrator__deps_enabled && [[ ${#INSTALL_RUNTIME_FOR_RUN[@]} -gt 0 ]]; then
    if ! lib__apt_mark_manual "${INSTALL_RUNTIME_FOR_RUN[@]}"; then
      MANIFEST_STATUS='failed'
      MANIFEST_MODULES_FAILED+=('dependencies:mark-manual')
      INSTALL_FAILED+=('dependencies:mark-manual')
      lib__log_error 'Failed to protect runtime dependencies.'
      orchestrator__apt_snapshot_after
      MANIFEST_INSTALLED_BY_US=("${APT_INSTALLED_BY_US[@]}")
      lib__state_unlock
      return 1
    fi
  fi

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 0 && ${#INSTALL_BUILD_ONLY[@]} -gt 0 ]]; then
    if ! lib__apt_mark_auto "${INSTALL_BUILD_ONLY[@]}"; then
      MANIFEST_STATUS='failed'
      MANIFEST_MODULES_FAILED+=('dependencies:mark-auto')
      INSTALL_FAILED+=('dependencies:mark-auto')
      lib__log_error 'Failed to mark build dependencies as automatically installed.'
      orchestrator__apt_snapshot_after
      MANIFEST_INSTALLED_BY_US=("${APT_INSTALLED_BY_US[@]}")
      lib__state_unlock
      return 1
    fi

    MANIFEST_AUTO_MARKED=("${INSTALL_BUILD_ONLY[@]}")
  fi

  for index in "${!INSTALL_QUEUE[@]}"; do
    module_file="${INSTALL_QUEUE[$index]}"
    key="${INSTALL_KEYS[$index]}"
    module="${INSTALL_NAMES[$index]}"
    module_ok=1

    if ! orchestrator__module_needed "$module_file"; then
      continue
    fi

    if orchestrator__module_blocked "$module_file"; then
      INSTALL_SKIPPED+=("$module")
      MANIFEST_MODULES_SKIPPED+=("$module")
      _MODULE_SKIPPED["$module_file"]=1
      lib__log_warn "$key: skipped because a dependency failed."
      continue
    fi

    # Once sudo credentials are cached (for example after the first phase),
    # keep them fresh from the main process.
    if [[ $EUID -ne 0 ]] && sudo -n true 2> /dev/null; then
      lib__start_sudo_keepalive
    fi

    # shellcheck disable=SC1090
    source "$module_file"

    lib__state_module_init "$key" "$module_file"
    MODULE_NAME="$module"

    if orchestrator__phase_enabled "$module_file" install; then
      if [[ "$INSTALL_FORCE" -eq 0 ]] \
        && ! lib__state_phase_marked "$key" install \
        && ! lib__state_is_external "$key" \
        && _module_is_present "$module_file"; then
        lib__state_mark_external "$key"
        lib__log_info "$key: program is already present; marking it external and keeping it."
      fi

      if orchestrator__should_skip "$key" install "$module_file"; then
        if lib__state_is_external "$key" && [[ "$INSTALL_FORCE" -eq 0 ]]; then
          lib__log_info "$key: external program, install skipped."
        else
          lib__log_info "$key: install already done, skipping."
        fi
      else
        set +e
        lib__state_run_phase "$key" install "$module_file" "${module}__install"
        phase_rc=$?
        set -e

        if [[ "$phase_rc" -ne 0 ]]; then
          failed=1
          module_ok=0
          _MODULE_FAILED["$module_file"]=1
          INSTALL_FAILED+=("$module:install")
          MANIFEST_MODULES_FAILED+=("$module:install")
          failed_entries+=("$module:install")
          if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
            break
          fi
          continue
        fi

        if [[ "$INSTALL_FORCE" -eq 1 ]]; then
          lib__state_clear_external "$key"
        fi
      fi
    fi

    if orchestrator__phase_enabled "$module_file" configure; then
      if [[ "$INSTALL_FORCE" -eq 0 ]] \
        && ! lib__state_has_install "$key" \
        && _module_is_present "$module_file"; then
        lib__state_mark_external "$key"
        lib__log_info "$key: program is already present; marking it external and keeping it."
      fi

      if ! lib__state_has_install "$key"; then
        lib__log_error "$key: program is not installed; run install first."
        failed=1
        module_ok=0
        INSTALL_FAILED+=("$module:configure")
        MANIFEST_MODULES_FAILED+=("$module:configure")
        failed_entries+=("$module:configure")
        if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
          break
        fi
        continue
      fi

      if orchestrator__should_skip "$key" configure "$module_file"; then
        lib__log_info "$key: configure already done, skipping."
      else
        set +e
        lib__state_run_phase "$key" configure "$module_file" "${module}__configure"
        phase_rc=$?
        set -e

        if [[ "$phase_rc" -ne 0 ]]; then
          failed=1
          module_ok=0
          INSTALL_FAILED+=("$module:configure")
          MANIFEST_MODULES_FAILED+=("$module:configure")
          failed_entries+=("$module:configure")
          if [[ "$INSTALL_KEEP_GOING" -eq 0 ]]; then
            break
          fi
        fi
      fi
    fi

    if [[ "$module_ok" -eq 1 ]]; then
      INSTALL_SUCCEEDED+=("$module")
      MANIFEST_MODULES_SUCCEEDED+=("$module")
    fi
  done

  orchestrator__apt_snapshot_after
  MANIFEST_INSTALLED_BY_US=("${APT_INSTALLED_BY_US[@]}")

  if [[ "$INSTALL_KEEP_BUILD_DEPS" -eq 0 ]] \
    && { [[ "$failed" -eq 0 ]] || [[ "$INSTALL_FORCE_CLEAN" -eq 1 ]]; }; then
    if ! orchestrator__cleanup; then
      cleanup_failed=1
      failed_entries+=('cleanup:build-deps')
    fi
  fi

  if [[ "$failed" -eq 0 && "$cleanup_failed" -eq 0 ]]; then
    MANIFEST_STATUS='success'
    lib__state_unlock
    lib__log_success 'All selected modules are installed.'
    return 0
  fi

  if [[ "$cleanup_failed" -eq 1 ]]; then
    MANIFEST_STATUS='cleanup-failed'
    lib__log_error 'Cleanup finished with errors.'
  else
    MANIFEST_STATUS='failed'
    lib__log_error 'Installation finished with errors.'
  fi

  lib__state_unlock
  orchestrator__print_resume "${failed_entries[@]}"
  return 1
}
