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
