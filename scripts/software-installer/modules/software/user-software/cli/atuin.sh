atuin__get_dependencies() {
  return 0
}

atuin__install() {
  lib__wget_download 'https://github.com/atuinsh/atuin/releases/latest/download/atuin-x86_64-unknown-linux-gnu.tar.gz'
  lib__mv_to_local_bin 'atuin'
}

atuin__configure() {
  return 0
}
