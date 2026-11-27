exiftool__get_build_dependencies() {
  return 0
}

exiftool__get_runtime_dependencies() {
  return 0
}

exiftool__install() {
  lib__apt_install libimage-exiftool-perl
}

exiftool__configure() {
  return 0
}

exiftool__is_installed() {
  lib__apt_is_installed libimage-exiftool-perl
}

exiftool__remove() {
  lib__apt_remove libimage-exiftool-perl
}

exiftool__deconfigure() {
  return 0
}
