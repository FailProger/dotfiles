polybar__get_build_dependencies() {
  return 0
}

polybar__get_runtime_dependencies() {
  return 0
}

polybar__install() {
  lib__apt_install polybar
}

polybar__configure() {
  lib__cp_config 'polybar'
}

polybar__is_installed() {
  lib__apt_is_installed polybar
}

polybar__remove() {
  lib__apt_remove polybar
}

polybar__deconfigure() {
  rm -rf "$HOME/.config/polybar"
}
