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
