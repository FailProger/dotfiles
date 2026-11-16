happ__get_dependencies() {
  return 0
}

happ__install() {
  rm -f ./Happ.linux.x64.deb

  lib__wget_download 'https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb'
  lib__apt_install ./Happ.linux.x64.deb

  rm -f ./Happ.linux.x64.deb
}

happ__configure() {
  return 0
}
