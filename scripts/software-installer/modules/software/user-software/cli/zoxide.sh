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
