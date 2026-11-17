i3__get_dependencies() {
  # i3 itself depends on its runtime libraries. The desktop environment
  # (xorg, dmenu, fonts, i3lock, xss-lock) is installed only when requested.
  return 0
}

i3__install() {
  lib__apt_install i3
}

i3__configure() {
  lib__cp_config 'i3'
}
