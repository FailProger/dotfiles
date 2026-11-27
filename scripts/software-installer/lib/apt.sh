lib__apt_is_installed() {
  local package="${1:?'Dont get package name!'}"

  [[ "$(dpkg-query -W -f='${Status}' "$package" 2> /dev/null)" == 'install ok installed' ]]
}

# Internal: set after a successful apt-get update in this process.
LIB_APT__UPDATED=''

# Run apt/dpkg without questions. sudo resets the environment, so the
# non-interactive settings are passed explicitly to the command.
lib__apt_run() {
  lib__as_root env \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    APT_LISTCHANGES_FRONTEND=none \
    NEEDRESTART_MODE=a \
    UCF_FORCE_CONFFOLD=1 \
    "$@"
}

# Refresh apt package lists once per process. Modules that add a repository
# must call this with --force, because the initial dependency batch already
# refreshed the lists before the repository existed.
lib__apt_update() {
  local force=0

  case "${1:-}" in
    --force|-f)
      force=1
      ;;
    '')
      ;;
    *)
      lib__log_error "Unknown option for lib__apt_update: $1"
      return 1
      ;;
  esac

  if [[ "$force" -eq 0 && -n "${LIB_APT__UPDATED:-}" ]]; then
    return 0
  fi

  lib__apt_run apt-get update || return 1
  LIB_APT__UPDATED=1
}

# Install only missing apt packages. Deduplication happens here, not in the
# orchestrator, so modules can return overlapping dependency lists.
lib__apt_install() {
  local -a packages=()
  local -a missing=()
  local package
  local need_update=0

  mapfile -t packages < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++')

  for package in "${packages[@]}"; do
    # A local .deb is installed by path; dpkg-query cannot check it in advance.
    if [[ -f "$package" ]] || ! lib__apt_is_installed "$package"; then
      missing+=("$package")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  lib__log_info "Installing apt packages: ${missing[*]}"

  for package in "${missing[@]}"; do
    if [[ ! -f "$package" ]]; then
      need_update=1
      break
    fi
  done

  if [[ "$need_update" -eq 1 && -z "${LIB_APT__UPDATED:-}" ]]; then
    lib__apt_update || return 1
  fi

  lib__apt_run apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "${missing[@]}"
}

lib__apt_available() {
  local package="${1:?'Dont get package name!'}"
  local candidate

  candidate="$(apt-cache policy "$package" 2> /dev/null \
    | awk '/Candidate:/ { print $2; exit }' || true)"

  [[ -n "$candidate" && "$candidate" != '(none)' ]]
}

lib__apt_lists_present() {
  find /var/lib/apt/lists -maxdepth 1 -name '*Packages*' -print -quit 2> /dev/null | grep -q .
}

# Package metadata for a whole dependency batch, one line per package:
#   <status>\t<package>\t<version>\t<description>
# status is installed, missing (available but not installed) or unknown.
# Two batch calls replace a per-package apt-cache invocation for every name,
# which made plans with many dependencies look like they had hung.
lib__apt_metadata() {
  local -A installed_version=()
  local -A available_version=()
  local -A description_of=()
  local -a names=()
  local -a query=()
  local package
  local status
  local version
  local description

  mapfile -t names < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++')

  if [[ ${#names[@]} -eq 0 ]]; then
    return 0
  fi

  while IFS=$'\t' read -r package status version; do
    [[ "$status" == 'install ok installed' ]] || continue
    installed_version["$package"]="$version"
  done < <(dpkg-query -W -f='${Package}\t${Status}\t${Version}\n' "${names[@]}" 2> /dev/null || true)

  query=("${names[@]}")

  if [[ ${#query[@]} -gt 0 ]] && command -v apt-cache > /dev/null 2>&1; then
    while IFS=$'\t' read -r package version description; do
      available_version["$package"]="$version"
      description_of["$package"]="$description"
    done < <(
      apt-cache show --no-all-versions "${query[@]}" 2> /dev/null \
        | awk -F ': ' '
            /^Package: / { pkg = $2; ver = ""; desc = "" }
            /^Version: / { ver = $2 }
            /^Description(-[A-Za-z_]+)?: / && $1 != "Description-md5" && desc == "" { desc = $2 }
            /^$/ {
              if (pkg != "") {
                print pkg "\t" ver "\t" desc
                pkg = ""
              }
            }
            END {
              if (pkg != "") {
                print pkg "\t" ver "\t" desc
              }
            }
          '
    )
  fi

  for package in "${names[@]}"; do
    if [[ -n "${installed_version[$package]:-}" ]]; then
      printf 'installed\t%s\t%s\t%s\n' \
        "$package" "${installed_version[$package]}" "${description_of[$package]:-}"
    elif [[ -n "${available_version[$package]:-}" ]]; then
      printf 'missing\t%s\t%s\t%s\n' \
        "$package" "${available_version[$package]}" "${description_of[$package]:-}"
    else
      printf 'unknown\t%s\t?\t\n' "$package"
    fi
  done
}

# Drop dependency names that do not exist in the current distribution. This
# keeps optional time_t-transition names (libssl3/libssl3t64) usable on both
# Debian and Ubuntu without distro detection.
lib__apt_filter_available() {
  local status
  local package
  local version
  local description

  while IFS=$'\t' read -r status package version description; do
    case "$status" in
      installed|missing)
        printf '%s\n' "$package"
        ;;
      *)
        if [[ "${INSTALL_VERBOSE:-0}" -eq 1 ]]; then
          lib__log_info "Dependency package '$package' is not available on this distribution; skipping it." >&2
        fi
        ;;
    esac
  done < <(lib__apt_metadata "$@")
}

# Keep only package names that are installed or available in this
# distribution; used to hide intentional cross-distribution alternatives.
lib__apt_filter_installed_or_available() {
  local status
  local package
  local version
  local description

  while IFS=$'\t' read -r status package version description; do
    [[ "$status" == 'unknown' ]] && continue
    printf '%s\n' "$package"
  done < <(lib__apt_metadata "$@")
}

# Install the dependency batch in one apt transaction. This is the only place
# where build and runtime dependencies are installed together.
lib__apt_install_batch() {
  local -a requested=()
  local -a packages=()
  local package
  local all_installed=1

  mapfile -t requested < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++')

  if [[ ${#requested[@]} -eq 0 ]]; then
    return 0
  fi

  # Keep the common "everything is already here" case free of sudo.
  for package in "${requested[@]}"; do
    if ! lib__apt_is_installed "$package"; then
      all_installed=0
      break
    fi
  done

  if [[ "$all_installed" -eq 1 ]]; then
    return 0
  fi

  lib__apt_update || return 1
  mapfile -t packages < <(lib__apt_filter_available "${requested[@]}" | awk 'NF && !seen[$0]++')

  if [[ ${#packages[@]} -eq 0 ]]; then
    return 0
  fi

  all_installed=1
  for package in "${packages[@]}"; do
    if ! lib__apt_is_installed "$package"; then
      all_installed=0
      break
    fi
  done

  if [[ "$all_installed" -eq 1 ]]; then
    return 0
  fi

  lib__log_info "Installing dependency packages: ${packages[*]}"

  lib__apt_run apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "${packages[@]}"
}

# Packages that the user marked as manual before this run.
lib__apt_show_manual() {
  apt-mark showmanual 2> /dev/null | LC_ALL=C sort -u
}

lib__apt_show_auto() {
  apt-mark showauto 2> /dev/null | LC_ALL=C sort -u
}

# Installed package names, used for the manifest diff.
lib__apt_installed_list() {
  dpkg --get-selections 2> /dev/null \
    | awk '$2 == "install" { print $1 }' \
    | LC_ALL=C sort -u
}

# Ensure runtime dependencies are manual even when they were already installed
# as auto by a dev package. Without this, autoremove could remove a library
# that the installed program still needs.
lib__apt_mark_manual() {
  local -a packages=()
  local -A already_manual=()
  local package

  while IFS= read -r package; do
    [[ -n "$package" ]] && already_manual["$package"]=1
  done < <(lib__apt_show_manual)

  for package in "$@"; do
    [[ -n "$package" ]] || continue
    [[ -n "${already_manual[$package]:-}" ]] && continue
    if lib__apt_is_installed "$package"; then
      packages+=("$package")
    fi
  done

  if [[ ${#packages[@]} -eq 0 ]]; then
    return 0
  fi

  lib__apt_run apt-mark manual "${packages[@]}"
}

# Mark packages as automatically installed. Packages that are not installed
# are ignored: they can appear in a dependency declaration but be pulled in
# as a transitive dependency under a different name.
lib__apt_mark_auto() {
  local -a packages=()
  local -A already_auto=()
  local package

  while IFS= read -r package; do
    [[ -n "$package" ]] && already_auto["$package"]=1
  done < <(lib__apt_show_auto)

  for package in "$@"; do
    [[ -n "$package" ]] || continue
    [[ -n "${already_auto[$package]:-}" ]] && continue
    if lib__apt_is_installed "$package"; then
      packages+=("$package")
    fi
  done

  if [[ ${#packages[@]} -eq 0 ]]; then
    return 0
  fi

  lib__apt_run apt-mark auto "${packages[@]}"
}

# Preview what a global autoremove would remove.
lib__apt_autoremove_preview() {
  apt-get autoremove --purge -s 2> /dev/null \
    | awk '$1 == "Remv" || $1 == "Purg" { print $2 }' \
    | LC_ALL=C sort -u
}

lib__apt_autoremove() {
  lib__apt_run apt-get autoremove --purge -y
}

# Installed packages that depend on the given package. Used before a purge to
# avoid removing a build tool that the system still needs.
lib__apt_reverse_dependencies() {
  local package="${1:?'Dont get package name!'}"

  apt-cache rdepends --installed "$package" 2> /dev/null \
    | sed -n '/Reverse Depends:/,$p' \
    | tail -n +2 \
    | awk '{ print $1 }' \
    | grep -vx "$package" \
    | LC_ALL=C sort -u
}

# Purge packages that a module installed as its main program. If another
# installed package depends on one of them, nothing is removed and 3 is
# returned: the phase runner treats that as "kept", not as a failure.
lib__apt_remove() {
  local package
  local -a installed=()

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  for package in "$@"; do
    if lib__apt_is_installed "$package"; then
      installed+=("$package")
    fi
  done

  if [[ ${#installed[@]} -eq 0 ]]; then
    return 0
  fi

  for package in "${installed[@]}"; do
    if [[ -n "$(lib__apt_reverse_dependencies "$package")" ]]; then
      lib__log_warn "Keeping '$package': other installed packages depend on it."
      return 3
    fi
  done

  lib__apt_run apt-get purge -y "${installed[@]}"
}

# Print apt dependency metadata.
# Usage: lib__apt_print_dependencies <label> <verbose> [packages...]
# Without verbose only packages that need to be installed are shown.
lib__apt_print_dependencies() {
  local label="${1:-Dependencies}"
  local verbose="${2:-0}"
  shift 2 || true

  local -a packages=()
  local -a missing=()
  local -a installed=()
  local -a unknown=()
  local -a order=()
  local package
  local version
  local description
  local status
  local icon
  local icon_color
  local row_color
  local name_color
  local missing_color
  local name_width=0
  local version_width=0
  local width
  local desc_width
  local lists_present=0
  local -A status_of=()
  local -A version_of=()
  local -A description_of=()

  mapfile -t packages < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++' | sort)

  if [[ ${#packages[@]} -eq 0 ]]; then
    printf '  %s%s:%s none\n' "$UI_BOLD" "$label" "$UI_RESET"
    return 0
  fi

  if lib__apt_lists_present; then
    lists_present=1
  fi

  if ! command -v apt-cache > /dev/null 2>&1; then
    lib__log_warn 'apt-cache is not available; package metadata is limited.'
  elif [[ "$verbose" -eq 1 && "$lists_present" -eq 0 ]]; then
    lib__log_warn 'apt package cache is empty; dependency metadata may be incomplete.'
  fi

  while IFS=$'\t' read -r status package version description; do
    [[ -n "$package" ]] || continue

    status_of["$package"]="$status"
    version_of["$package"]="$version"
    description_of["$package"]="$description"

    case "$status" in
      installed)
        installed+=("$package")
        ;;
      missing)
        missing+=("$package")
        ;;
      *)
        unknown+=("$package")
        ;;
    esac

    (( ${#package} > name_width )) && name_width=${#package}
    (( ${#version} > version_width )) && version_width=${#version}
  done < <(lib__apt_metadata "${packages[@]}")

  if (( ${#missing[@]} > 0 )); then
    missing_color="$UI_YELLOW"
  else
    missing_color="$UI_GREEN"
  fi

  if (( ${#packages[@]} == 1 )); then
    printf '  %s%s:%s 1 package · %s%s installed%s · %s%s to install%s' \
      "$UI_BOLD" "$label" "$UI_RESET" \
      "$UI_DIM" "${#installed[@]}" "$UI_RESET" \
      "$missing_color" "${#missing[@]}" "$UI_RESET"
  else
    printf '  %s%s:%s %s packages · %s%s installed%s · %s%s to install%s' \
      "$UI_BOLD" "$label" "$UI_RESET" \
      "${#packages[@]}" \
      "$UI_DIM" "${#installed[@]}" "$UI_RESET" \
      "$missing_color" "${#missing[@]}" "$UI_RESET"
  fi

  if (( ${#unknown[@]} > 0 )); then
    if [[ "$lists_present" -eq 1 ]]; then
      printf ' · %s%s not available%s' "$UI_RED" "${#unknown[@]}" "$UI_RESET"
    else
      printf ' · %s%s unknown%s' "$UI_RED" "${#unknown[@]}" "$UI_RESET"
    fi
  fi

  printf '\n'

  if [[ "$verbose" -eq 0 ]]; then
    # Unknown names are cross-distribution alternatives that do not exist
    # here; they are not installed, so only their count is reported above.
    order=("${missing[@]}")

    if [[ ${#order[@]} -eq 0 ]]; then
      if (( ${#unknown[@]} > 0 )); then
        printf '    %snothing to install%s\n' "$UI_DIM" "$UI_RESET"
      else
        printf '    %sall dependencies are already installed%s\n' "$UI_DIM" "$UI_RESET"
      fi
      return 0
    fi

    for package in "${order[@]}"; do
      printf '    %s%s%s %s\n' "$UI_GREEN" "$UI_ADD" "$UI_RESET" "$package"
    done

    return 0
  fi

  order=("${missing[@]}" "${unknown[@]}" "${installed[@]}")

  if [[ ${#order[@]} -eq 0 ]]; then
    printf '    %sall dependencies are already installed%s\n' "$UI_DIM" "$UI_RESET"
    return 0
  fi

  width="$(lib__ui_width)"
  desc_width=$((width - 2 - 1 - 1 - name_width - 2 - version_width - 2))
  ((desc_width < 10)) && desc_width=0

  for package in "${order[@]}"; do
    status="${status_of[$package]}"
    version="${version_of[$package]}"
    description="${description_of[$package]}"

    if [[ "$status" == 'unknown' && -z "$description" ]]; then
      if [[ "$lists_present" -eq 1 ]]; then
        description='not available in this distribution'
      else
        description='apt package lists are empty'
      fi
    fi

    case "$status" in
      installed)
        icon="$UI_OK"
        icon_color="$UI_DIM"
        row_color="$UI_DIM"
        name_color="$UI_DIM"
        ;;
      missing)
        icon="$UI_ADD"
        icon_color="$UI_GREEN"
        row_color=''
        name_color=''
        ;;
      *)
        icon="$UI_UNKNOWN"
        icon_color="$UI_RED"
        row_color=''
        name_color=''
        ;;
    esac

    printf '  %s%s%s %s%-*s%s  ' \
      "$icon_color" "$icon" "$UI_RESET" \
      "$name_color" "$name_width" "$package" "$UI_RESET"

    if ((desc_width > 0)) && [[ -n "$description" ]]; then
      printf '%s%-*s%s  %s%s%s\n' \
        "$row_color" "$version_width" "$version" "$UI_RESET" \
        "$UI_DIM" "$(lib__ui_truncate "$desc_width" "$description")" "$UI_RESET"
    else
      printf '%s%s%s\n' "$row_color" "$version" "$UI_RESET"
    fi
  done
}
