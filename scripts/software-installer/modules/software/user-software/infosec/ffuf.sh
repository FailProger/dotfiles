ffuf__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

ffuf__get_runtime_dependencies() {
  return 0
}

ffuf__install() {
  lib__wget_download_github_release 'ffuf/ffuf' 'ffuf_.*_linux_amd64.tar.gz'
  lib__mv_to_local_bin 'ffuf'
}

ffuf__configure() {
  return 0
}

ffuf__is_installed() {
  command -v ffuf > /dev/null 2>&1
}

ffuf__remove() {
  lib__as_root rm -f /usr/local/bin/ffuf
}

ffuf__deconfigure() {
  return 0
}
