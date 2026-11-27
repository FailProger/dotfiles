zsh__get_build_dependencies() {
  return 0
}

zsh__get_runtime_dependencies() {
  return 0
}

zsh__install() {
  lib__apt_install zsh
}

zsh__configure() {
  lib__as_root chsh -s "$(command -v zsh)" "$USER"

  lib__cp_config 'zsh/zshenv' "$HOME/.zshenv"
  lib__cp_config 'zsh/zprofile' "$HOME/.zprofile"
  lib__cp_config 'zsh/zshrc' "$HOME/.zshrc"
  lib__cp_config 'zsh/zsh_custom' "$HOME/.zsh_custom"
}

zsh__is_installed() {
  lib__apt_is_installed zsh
}

zsh__remove() {
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" == *zsh ]]; then
    lib__log_warn 'zsh is the current login shell; change the shell before removing it.'
    return 3
  fi

  lib__apt_remove zsh
}

zsh__deconfigure() {
  rm -f "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc"
  rm -rf "$HOME/.zsh_custom"
}
