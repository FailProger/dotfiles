pipewire__get_dependencies() {
  return 0
}

pipewire__install() {
  lib__apt_install pipewire pipewire-pulse wireplumber
}

pipewire__configure() {
  systemctl --user enable --now pipewire pipewire-pulse wireplumber
}
