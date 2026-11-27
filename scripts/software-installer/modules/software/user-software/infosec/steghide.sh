steghide__get_build_dependencies() {
  return 0
}

steghide__get_runtime_dependencies() {
  return 0
}

steghide__install() {
  lib__apt_install steghide
}

steghide__configure() {
  return 0
}

steghide__is_installed() {
  lib__apt_is_installed steghide
}

steghide__remove() {
  lib__apt_remove steghide
}

steghide__deconfigure() {
  return 0
}
