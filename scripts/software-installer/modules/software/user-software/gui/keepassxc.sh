keepassxc__get_dependencies() {
  local deps='
  software-properties-common
  '
  echo "$deps"
}

keepassxc__install() {
  lib__apt_run add-apt-repository -y ppa:phoerious/keepassxc
  lib__apt_update
  lib__apt_install keepassxc
}

keepassxc__configure() {
  return 0
}
