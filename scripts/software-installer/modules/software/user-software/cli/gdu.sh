gdu__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

gdu__get_runtime_dependencies() {
  return 0
}

gdu__install() {
  lib__wget_download 'https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz'
  lib__mv_to_local_bin 'gdu'
}

gdu__configure() {
  return 0
}

gdu__is_installed() {
  command -v gdu > /dev/null 2>&1
}

gdu__remove() {
  lib__as_root rm -f /usr/local/bin/gdu
}

gdu__deconfigure() {
  return 0
}
