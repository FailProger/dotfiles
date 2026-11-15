picom__get_dependencies() {
  return 0
}

picom__install() {
  lib__apt_install picom
}

picom__configure() {
  lib__cp_config 'picom'
}
