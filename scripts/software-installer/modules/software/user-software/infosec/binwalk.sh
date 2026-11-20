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
