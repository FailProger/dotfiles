rust__get_build_dependencies() {
  return 0
}

rust__get_runtime_dependencies() {
  local deps='
  curl
  ca-certificates
  gcc
  libc6-dev
  '
  echo "$deps"
}

rust__install() {
  local had_toolchain=0

  if [[ -e "$HOME/.cargo" || -e "$HOME/.rustup" ]]; then
    had_toolchain=1
  fi

  /usr/bin/bash -s << 'EOF'
curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
EOF

  if [[ "$had_toolchain" -eq 0 ]]; then
    lib__state_mark_owned
  fi
}

rust__configure() {
  return 0
}

rust__remove() {
  local file

  if ! lib__state_is_owned; then
    lib__log_info 'Rust was not installed by this installer; keeping it.'
    lib__state_mark_kept
    return 0
  fi

  rm -rf "$HOME/.rustup" "$HOME/.cargo"

  # rustup adds the toolchain to shell startup files. Remove only the
  # Rust-specific lines, never the whole file.
  for file in \
    "$HOME/.profile" \
    "$HOME/.bash_profile" \
    "$HOME/.bashrc" \
    "$HOME/.zshenv" \
    "$HOME/.zprofile" \
    "$HOME/.zshrc"; do
    [[ -f "$file" ]] || continue
    sed -i -e '/\.cargo\/env/d' -e '/\.cargo\/bin/d' "$file"
  done

  lib__log_info 'Removed the Rust toolchain installed for the build.'
}
