git__get_dependencies() {
  local deps='
  ca-certificates
  '
  echo "$deps"
}

git__install() {
  lib__apt_install git
}

git__configure() {
  lib__cp_config 'git'
}
