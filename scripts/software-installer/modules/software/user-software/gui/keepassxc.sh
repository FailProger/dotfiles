keepassxc__get_build_dependencies() {
  local deps='
  software-properties-common
  '
  echo "$deps"
}

keepassxc__get_runtime_dependencies() {
  # The PPA stays in apt sources, so HTTPS must keep working.
  local deps='
  ca-certificates
  '
  echo "$deps"
}

keepassxc__install() {
  lib__apt_run add-apt-repository -y ppa:phoerious/keepassxc
  lib__apt_update --force
  lib__apt_install keepassxc
}

keepassxc__configure() {
  return 0
}

keepassxc__is_installed() {
  lib__apt_is_installed keepassxc
}

keepassxc__remove() {
  lib__apt_run add-apt-repository --remove -y ppa:phoerious/keepassxc 2> /dev/null || true
  lib__apt_remove keepassxc
}

keepassxc__deconfigure() {
  return 0
}
