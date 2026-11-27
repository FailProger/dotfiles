obs_studio__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

obs_studio__get_runtime_dependencies() {
  return 0
}

obs_studio__install() {
  rm -f obs-studio.deb

  lib__wget_download 'https://github.com/obsproject/obs-studio/releases/download/32.2.2/OBS-Studio-32.2.2-Ubuntu-24.04-x86_64.deb' 'obs-studio.deb'
  lib__apt_install ./obs-studio.deb

  rm -f obs-studio.deb
}

obs_studio__configure() {
  return 0
}

obs_studio__is_installed() {
  lib__apt_is_installed obs-studio
}

obs_studio__remove() {
  lib__apt_remove obs-studio
}

obs_studio__deconfigure() {
  return 0
}
