xxd__get_build_dependencies() {
  return 0
}

xxd__get_runtime_dependencies() {
  return 0
}

xxd__install() {
  lib__apt_install xxd
}

xxd__configure() {
  return 0
}

xxd__is_installed() {
  lib__apt_is_installed xxd
}

xxd__remove() {
  lib__apt_remove xxd
}

xxd__deconfigure() {
  return 0
}
