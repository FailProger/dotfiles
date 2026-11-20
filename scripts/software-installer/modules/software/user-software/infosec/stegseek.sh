stegseek__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

stegseek__get_runtime_dependencies() {
  return 0
}

stegseek__install() {
  rm -f ./stegseek_*-1.deb

  lib__wget_download_github_release 'RickdeJager/stegseek' 'stegseek_.*-1.deb'
  lib__apt_install ./stegseek_*-1.deb

  rm -f ./stegseek_*-1.deb
}

stegseek__configure() {
  return 0
}
