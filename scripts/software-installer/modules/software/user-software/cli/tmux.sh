tmux__get_build_dependencies() {
  return 0
}

tmux__get_runtime_dependencies() {
  return 0
}

tmux__install() {
  lib__apt_install tmux
}

tmux__configure() {
  lib__cp_config 'tmux'
}

tmux__is_installed() {
  lib__apt_is_installed tmux
}

tmux__remove() {
  lib__apt_remove tmux
}

tmux__deconfigure() {
  rm -rf "$HOME/.config/tmux"
}
