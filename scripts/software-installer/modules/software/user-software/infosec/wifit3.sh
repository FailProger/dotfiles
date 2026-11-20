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
