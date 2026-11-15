cchef__get_dependencies() {
  return 0
}

cchef__install() {
  lib__wget_download_github_release 'roberson-io/cchef' 'cchef_.*_linux_amd64.tar.gz'
  lib__mv_to_local_bin 'cchef'
}

cchef__configure() {
  return 0
}
