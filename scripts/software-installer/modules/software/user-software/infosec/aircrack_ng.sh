aircrack_ng__get_build_dependencies() {
  return 0
}

aircrack_ng__get_runtime_dependencies() {
  return 0
}

aircrack_ng__install() {
  lib__apt_install aircrack-ng
}

aircrack_ng__configure() {
  return 0
}

aircrack_ng__is_installed() {
  lib__apt_is_installed aircrack-ng
}

aircrack_ng__remove() {
  lib__apt_remove aircrack-ng
}

aircrack_ng__deconfigure() {
  return 0
}
