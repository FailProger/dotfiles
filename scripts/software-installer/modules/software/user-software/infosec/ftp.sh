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
