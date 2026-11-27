wifit3__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

wifit3__get_runtime_dependencies() {
  return 0
}

wifit3__install() {
  lib__wget_download 'https://github.com/derv82/wifit3/releases/latest/download/wifit3-linux-x64'

  lib__install_binary 'wifit3-linux-x64' 'wifit3'
  rm -f 'wifit3-linux-x64'
}

wifit3__configure() {
  return 0
}

wifit3__is_installed() {
  command -v wifit3 > /dev/null 2>&1
}

wifit3__remove() {
  lib__as_root rm -f /usr/local/bin/wifit3
}

wifit3__deconfigure() {
  return 0
}
