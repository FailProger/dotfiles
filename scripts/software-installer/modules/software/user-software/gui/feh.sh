
feh__get_build_dependencies() {
  return 0
}

feh__get_runtime_dependencies() {
  return 0
}

feh__install() {
  lib__apt_install feh
}

feh__configure() {
  return 0
}

feh__is_installed() {
  lib__apt_is_installed feh
}

feh__remove() {
  lib__apt_remove feh
}

feh__deconfigure() {
  return 0
}
