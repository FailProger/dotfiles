zsh__get_dependencies() {
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
