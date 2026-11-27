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

# Used by the planner: an existing rustup toolchain is used as is and is not
# reinstalled or cleaned up as a build-only module.
rust__is_installed() {
  [[ -x "$HOME/.cargo/bin/cargo" || -x "$HOME/.cargo/bin/rustup" ]]
}

rust__install() {
  /usr/bin/bash -s << 'EOF'
curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
EOF
}

rust__configure() {
  return 0
}

rust__remove() {
  local file

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
}

rust__deconfigure() {
  return 0
}
