i3__get_dependencies() {
  local deps='
  xorg
  dmenu
  fonts
  i3lock
  xss-lock
  '
  echo "$deps"
}

i3__install() {
  lib__apt_install i3
}

i3__configure() {
  lib__cp_config 'i3'
}
