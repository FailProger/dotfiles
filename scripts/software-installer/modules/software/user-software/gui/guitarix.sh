guitarix__get_build_dependencies() {
  return 0
}

guitarix__get_runtime_dependencies() {
  return 0
}

guitarix__install() {
  lib__apt_install guitarix
}

guitarix__configure() {
  return 0
}

guitarix__is_installed() {
  lib__apt_is_installed guitarix
}

guitarix__remove() {
  lib__apt_remove guitarix
}

guitarix__deconfigure() {
  return 0
}
