bat__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

bat__get_runtime_dependencies() {
  return 0
}

bat__install() {
  rm -f ./bat_*_amd64.deb

  lib__wget_download_github_release 'sharkdp/bat' 'bat_.*_amd64.deb'
  lib__apt_install ./bat_*_amd64.deb
  rm -f ./bat_*_amd64.deb
}

bat__configure() {
  return 0
}

bat__is_installed() {
  lib__apt_is_installed bat
}

bat__remove() {
  lib__apt_remove bat
}

bat__deconfigure() {
  return 0
}
