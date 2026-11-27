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

i3__is_installed() {
  lib__apt_is_installed i3
}

i3__remove() {
  lib__apt_remove i3
}

i3__deconfigure() {
  rm -rf "$HOME/.config/i3"
}
