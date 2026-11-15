exiftool__get_dependencies() {
  return 0
}

exiftool__install() {
  lib__apt_install libimage-exiftool-perl
}

exiftool__configure() {
  return 0
}
