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
