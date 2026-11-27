binwalk__get_build_dependencies() {
  return 0
}

binwalk__get_runtime_dependencies() {
  return 0
}

binwalk__install() {
  lib__apt_install binwalk
}

binwalk__configure() {
  return 0
}

binwalk__is_installed() {
  lib__apt_is_installed binwalk
}

binwalk__remove() {
  lib__apt_remove binwalk
}

binwalk__deconfigure() {
  return 0
}
