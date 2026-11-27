happ__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

happ__get_runtime_dependencies() {
  local deps='
  libopengl0
  '
  echo "$deps"
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

happ__is_installed() {
  lib__apt_is_installed happ || lib__apt_is_installed happ-desktop
}

happ__remove() {
  lib__apt_remove happ happ-desktop
}

happ__deconfigure() {
  return 0
}
