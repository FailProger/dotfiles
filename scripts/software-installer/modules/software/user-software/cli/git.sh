git__get_build_dependencies() {
  return 0
}

git__get_runtime_dependencies() {
  local deps='
  ca-certificates
  '
  echo "$deps"
}

git__install() {
  local was_installed=0

  if lib__apt_is_installed git; then
    was_installed=1
  fi

  lib__apt_install git

  if [[ "$was_installed" -eq 0 ]]; then
    lib__state_mark_owned
  fi
}

git__configure() {
  lib__cp_config 'git'
}

git__remove() {
  if ! lib__state_is_owned; then
    lib__log_info 'Git was not installed by this installer; keeping it.'
    lib__state_mark_kept
    return 0
  fi

  lib__apt_remove git
}
