atuin__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

atuin__get_runtime_dependencies() {
  return 0
}

atuin__install() {
  lib__wget_download 'https://github.com/atuinsh/atuin/releases/latest/download/atuin-x86_64-unknown-linux-gnu.tar.gz'
  lib__mv_to_local_bin 'atuin'
}

atuin__configure() {
  return 0
}

atuin__is_installed() {
  command -v atuin > /dev/null 2>&1
}

atuin__remove() {
  lib__as_root rm -f /usr/local/bin/atuin
}

atuin__deconfigure() {
  return 0
}
