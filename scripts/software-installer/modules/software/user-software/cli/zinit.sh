zinit__get_build_dependencies() {
  local deps='
  ca-certificates
  curl
  '
  echo "$deps"
}

zinit__get_runtime_dependencies() {
  local deps='
  git
  '
  echo "$deps"
}

zinit__install() {
  /usr/bin/bash -s << 'EOF'
NO_INPUT=1 NO_ANNEXES=1 NO_EDIT=1 NO_TUTORIAL=1 \
  bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
EOF
}

zinit__configure() {
  return 0
}

zinit__is_installed() {
  [[ -d "$HOME/.local/share/zinit" ]]
}

zinit__remove() {
  rm -rf "$HOME/.local/share/zinit" "$HOME/.zinit"
}

zinit__deconfigure() {
  return 0
}
