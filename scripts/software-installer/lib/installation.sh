lib__install_binary() {
  local src="${1:?'Dont get source file!'}"
  local name="${2:?'Dont get binary name!'}"

  lib__as_root install -d -m 755 '/usr/local/bin'
  lib__as_root install -m 755 "$src" "/usr/local/bin/$name"
}

# Extract a downloaded archive from the current directory and install the
# contained executable to /usr/local/bin/<name>.
lib__mv_to_local_bin() {
  local name="${1:?'Dont get package name!'}"
  local workdir
  local archive
  local candidate
  local binary=''
  local -a executables=()
  local -a archives=()

  workdir="$(mktemp -d)"

  for archive in "$name"*; do
    [[ -f "$archive" ]] || continue
    archives+=("$archive")

    case "$archive" in
      *.tar.gz|*.tgz)
        if ! tar -xzf "$archive" -C "$workdir"; then
          lib__log_error "Failed to extract $archive."
          rm -rf "$workdir"
          return 1
        fi
        ;;
      *.tar.xz|*.txz)
        lib__require_command xz xz-utils || {
          rm -rf "$workdir"
          return 1
        }

        if ! tar -xJf "$archive" -C "$workdir"; then
          lib__log_error "Failed to extract $archive."
          rm -rf "$workdir"
          return 1
        fi
        ;;
      *.tar.bz2|*.tbz2)
        lib__require_command bzip2 bzip2 || {
          rm -rf "$workdir"
          return 1
        }

        if ! tar -xjf "$archive" -C "$workdir"; then
          lib__log_error "Failed to extract $archive."
          rm -rf "$workdir"
          return 1
        fi
        ;;
      *.zip)
        lib__require_command unzip unzip || {
          rm -rf "$workdir"
          return 1
        }

        if ! unzip -qo "$archive" -d "$workdir"; then
          lib__log_error "Failed to extract $archive."
          rm -rf "$workdir"
          return 1
        fi
        ;;
      *)
        lib__log_warn "Skipping unknown archive: $archive"
        continue
        ;;
    esac
  done

  mapfile -t executables < <(find "$workdir" -type f -perm -u+x -print)

  for candidate in "${executables[@]}"; do
    if [[ "$(basename "$candidate")" == "$name" ]]; then
      binary="$candidate"
      break
    fi
  done

  if [[ -z "$binary" ]]; then
    for candidate in "${executables[@]}"; do
      case "$(basename "$candidate")" in
        *"$name"*)
          binary="$candidate"
          break
          ;;
      esac
    done
  fi

  if [[ -z "$binary" && ${#executables[@]} -eq 1 ]]; then
    binary="${executables[0]}"
  fi

  if [[ -z "$binary" ]]; then
    lib__log_error "Cannot find '$name' executable in the downloaded archive."
    rm -rf "$workdir"
    return 1
  fi

  lib__install_binary "$binary" "$name"

  rm -rf "$workdir"
  if [[ ${#archives[@]} -gt 0 ]]; then
    rm -f "${archives[@]}"
  fi

  return 0
}
