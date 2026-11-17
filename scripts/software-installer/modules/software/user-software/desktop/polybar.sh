polybar__get_dependencies() {
  # Fonts are a runtime choice; install the fonts module separately.
  return 0
}

polybar__install() {
  lib__apt_install polybar
}

polybar__configure() {
  lib__cp_config 'polybar'
}
