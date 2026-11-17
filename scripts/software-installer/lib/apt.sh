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

# Refresh apt package lists once per process.
lib__apt_update() {
  if [[ -n "${LIB_APT__UPDATED:-}" ]]; then
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

# Print apt dependency metadata.
# Without --verbose only packages that need to be installed are shown.
lib__apt_print_dependencies() {
  local verbose="${1:-0}"
  shift || true

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
  local -A status_of=()
  local -A version_of=()
  local -A description_of=()

  mapfile -t packages < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++' | sort)

  if [[ ${#packages[@]} -eq 0 ]]; then
    printf '  %sDependencies:%s none\n' "$UI_BOLD" "$UI_RESET"
    return 0
  fi

  if ! command -v apt-cache > /dev/null 2>&1; then
    lib__log_warn 'apt-cache is not available; package metadata is limited.'
  elif [[ "$verbose" -eq 1 ]] \
    && ! find /var/lib/apt/lists -maxdepth 1 -name '*Packages*' -print -quit 2> /dev/null | grep -q .; then
    lib__log_warn 'apt package cache is empty; dependency metadata may be incomplete.'
  fi

  for package in "${packages[@]}"; do
    if lib__apt_is_installed "$package"; then
      status='installed'
      version="$(dpkg-query -W -f='${Version}' "$package" 2> /dev/null || true)"
      installed+=("$package")
    else
      version="$(apt-cache policy "$package" 2> /dev/null \
        | awk '/Candidate:/ { print $2; exit }' || true)"

      if [[ -z "$version" || "$version" == '(none)' ]]; then
        status='unknown'
        version='?'
        unknown+=("$package")
      else
        status='missing'
        missing+=("$package")
      fi
    fi

    description=''
    if [[ "$status" != 'installed' || "$verbose" -eq 1 ]]; then
      description="$(apt-cache show "$package" 2> /dev/null \
        | awk -F': ' '/^Description(-[a-zA-Z]+)?:/ { print $2; exit }' || true)"
    fi

    status_of["$package"]="$status"
    version_of["$package"]="$version"
    description_of["$package"]="$description"

    (( ${#package} > name_width )) && name_width=${#package}
    (( ${#version} > version_width )) && version_width=${#version}
  done

  if (( ${#missing[@]} > 0 )); then
    missing_color="$UI_YELLOW"
  else
    missing_color="$UI_GREEN"
  fi

  if (( ${#packages[@]} == 1 )); then
    printf '  %sDependencies:%s 1 package · %s%s installed%s · %s%s to install%s' \
      "$UI_BOLD" "$UI_RESET" \
      "$UI_DIM" "${#installed[@]}" "$UI_RESET" \
      "$missing_color" "${#missing[@]}" "$UI_RESET"
  else
    printf '  %sDependencies:%s %s packages · %s%s installed%s · %s%s to install%s' \
      "$UI_BOLD" "$UI_RESET" \
      "${#packages[@]}" \
      "$UI_DIM" "${#installed[@]}" "$UI_RESET" \
      "$missing_color" "${#missing[@]}" "$UI_RESET"
  fi

  if (( ${#unknown[@]} > 0 )); then
    printf ' · %s%s unavailable%s' "$UI_RED" "${#unknown[@]}" "$UI_RESET"
  fi

  printf '\n'

  if [[ "$verbose" -eq 0 ]]; then
    order=("${missing[@]}" "${unknown[@]}")
  else
    order=("${missing[@]}" "${unknown[@]}" "${installed[@]}")
  fi

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
