feroxbuster__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  unzip
  '
  echo "$deps"
}

feroxbuster__get_runtime_dependencies() {
  return 0
}

feroxbuster__install() {
  rm -f feroxbuster*.deb feroxbuster*.deb.zip

  lib__wget_download 'https://github.com/epi052/feroxbuster/releases/latest/download/feroxbuster_amd64.deb.zip'

  unzip -o feroxbuster*.deb.zip
  rm -f feroxbuster*.deb.zip

  lib__apt_install ./feroxbuster*.deb

  rm -f feroxbuster*.deb
}

feroxbuster__configure() {
  return 0
}

feroxbuster__is_installed() {
  lib__apt_is_installed feroxbuster
}

feroxbuster__remove() {
  lib__apt_remove feroxbuster
}

feroxbuster__deconfigure() {
  return 0
}
