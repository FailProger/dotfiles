# Write a file. Content is read from stdin. The file is written as the current
# user when the destination directory is writable, and through sudo otherwise.
lib__file_write() {
  local path="${1:?'Dont get file path!'}"
  local mode="${2:-644}"
  local dir
  local tmp

  tmp="$(mktemp)"
  cat > "$tmp"
  dir="$(dirname "$path")"

  if mkdir -p "$dir" 2> /dev/null && [[ -w "$dir" ]]; then
    install -m "$mode" "$tmp" "$path"
  else
    lib__as_root install -D -m "$mode" "$tmp" "$path"
  fi

  rm -f "$tmp"
}

# Copy a managed config file or directory to the user's home.
# With no destination, the config is copied to $HOME/.config/<basename>.
# An explicit destination is treated as the exact target path.
# The destination is recreated from scratch, so repeated runs never nest
# copies inside the previous ones. Executable bits are preserved.
lib__cp_config() {
  local file="${1:?'Dont get file name!'}"
  local dst="${2:-$HOME/.config/$(basename "$1")}"
  local src

  if [[ -n "${DOTFILES_DIR:-}" ]]; then
    src="$DOTFILES_DIR/$file"
  else
    src="$file"
  fi

  if [[ ! -e "$src" ]]; then
    lib__log_error "Config path '$src' not found."
    return 1
  fi

  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"

  find "$dst" -type d -exec chmod 700 {} +
  find "$dst" -type f ! -perm -u+x -exec chmod 600 {} +
  find "$dst" -type f -perm -u+x -exec chmod 700 {} +
}
