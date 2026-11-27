zoxide__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

zoxide__get_runtime_dependencies() {
  return 0
}

zoxide__install() {
  lib__wget_download_github_release 'ajeetdsouza/zoxide' 'zoxide-.*-x86_64-unknown-linux-musl.tar.gz'
  lib__mv_to_local_bin 'zoxide'
}

zoxide__configure() {
  return 0
}

zoxide__is_installed() {
  command -v zoxide > /dev/null 2>&1
}

zoxide__remove() {
  lib__as_root rm -f /usr/local/bin/zoxide
}

zoxide__deconfigure() {
  return 0
}
