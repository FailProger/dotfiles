ftp__get_build_dependencies() {
  return 0
}

ftp__get_runtime_dependencies() {
  return 0
}

ftp__install() {
  lib__apt_install ftp
}

ftp__configure() {
  return 0
}

ftp__is_installed() {
  lib__apt_is_installed ftp
}

ftp__remove() {
  lib__apt_remove ftp
}

ftp__deconfigure() {
  return 0
}
