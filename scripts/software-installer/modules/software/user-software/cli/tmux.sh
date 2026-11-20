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
