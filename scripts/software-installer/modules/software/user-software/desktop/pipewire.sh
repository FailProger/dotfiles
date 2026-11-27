pipewire__get_build_dependencies() {
  return 0
}

pipewire__get_runtime_dependencies() {
  local deps='
  rtkit
  '
  echo "$deps"
}

pipewire__install() {
  local -a packages=(
    pipewire
    pipewire-pulse
    pipewire-jack
    wireplumber
  )

  lib__apt_install "${packages[@]}"
}

pipewire__configure() {
  systemctl --user enable --now pipewire pipewire-pulse wireplumber
  lib__cp_config 'pipewire'
  lib__as_root usermod -aG pipewire "$USER"
}

pipewire__is_installed() {
  lib__apt_is_installed pipewire && lib__apt_is_installed wireplumber
}

pipewire__remove() {
  lib__apt_remove pipewire pipewire-pulse pipewire-jack wireplumber
}

pipewire__deconfigure() {
  systemctl --user disable --now pipewire pipewire-pulse wireplumber 2> /dev/null || true
  rm -rf "$HOME/.config/pipewire"
  lib__as_root gpasswd -d "$USER" pipewire 2> /dev/null || true
}
