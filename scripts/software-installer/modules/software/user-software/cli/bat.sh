bat__get_dependencies() {
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
