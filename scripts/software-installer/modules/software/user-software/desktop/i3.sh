i3__get_build_dependencies() {
  return 0
}

i3__get_runtime_dependencies() {
  return 0
}

i3__install() {
  lib__apt_install i3
}

i3__configure() {
  lib__cp_config 'i3'
}
