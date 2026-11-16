keepassxc__get_dependencies() {
  local deps='
  software-properties-common
  '
  echo "$deps"
}

keepassxc__install() {
  lib__as_root add-apt-repository ppa:phoerious/keepassxc
  lib__as_root apt update
  lib__apt_install keepassxc
}

keepassxc__configure() {
  return 0
}
