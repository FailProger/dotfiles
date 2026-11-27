dmenu__get_build_dependencies() {
  return 0
}

dmenu__get_runtime_dependencies() {
  return 0
}

dmenu__install() {
  lib__apt_install dmenu j4-dmenu-desktop
}

dmenu__configure() {
  return 0
}

dmenu__is_installed() {
  lib__apt_is_installed dmenu && lib__apt_is_installed j4-dmenu-desktop
}

dmenu__remove() {
  lib__apt_remove dmenu j4-dmenu-desktop
}

dmenu__deconfigure() {
  return 0
}
