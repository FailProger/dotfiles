obs_studio__get_dependencies() {
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
