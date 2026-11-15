polybar__get_dependencies() {
  local deps='
  fonts
  '
  echo "$deps"
}

polybar__install() {
  lib__apt_install polybar
}

polybar__configure() {
  lib__cp_config 'polybar'
}
