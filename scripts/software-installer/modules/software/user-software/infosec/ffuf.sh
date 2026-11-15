ffuf__get_dependencies() {
  return 0
}

ffuf__install() {
  lib__wget_download_github_release 'ffuf/ffuf' 'ffuf_.*_linux_amd64.tar.gz'
  lib__mv_to_local_bin 'ffuf'
}

ffuf__configure() {
  return 0
}
