git__get_build_dependencies() {
  return 0
}

git__get_runtime_dependencies() {
  local deps='
  ca-certificates
  '
  echo "$deps"
}

# Used by the planner: git installed outside the installer is used as is.
git__is_installed() {
  lib__apt_is_installed git
}

git__install() {
  lib__apt_install git
}

git__configure() {
  lib__cp_config 'git'
}

git__remove() {
  lib__apt_remove git
}

git__deconfigure() {
  rm -rf "$HOME/.config/git"
}
