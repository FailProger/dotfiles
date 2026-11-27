eza__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

eza__get_runtime_dependencies() {
  return 0
}

eza__install() {
  lib__wget_download 'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz'
  lib__mv_to_local_bin 'eza'
}

eza__configure() {
  lib__cp_config 'eza'
}

eza__is_installed() {
  command -v eza > /dev/null 2>&1
}

eza__remove() {
  lib__as_root rm -f /usr/local/bin/eza
}

eza__deconfigure() {
  rm -rf "$HOME/.config/eza"
}
