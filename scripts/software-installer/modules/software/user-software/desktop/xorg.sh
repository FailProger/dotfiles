xorg__get_build_dependencies() {
  return 0
}

xorg__get_runtime_dependencies() {
  return 0
}

xorg__install() {
  # Minimal X session: server, startx, X utilities and keyboard tools.
  # Video drivers are hardware-specific; install xserver-xorg-video-all or a
  # concrete driver separately if the system does not have one yet.
  local -a packages=(
    xserver-xorg
    xinit
    xauth
    x11-xserver-utils
    x11-xkb-utils
    xclip
  )

  lib__apt_install "${packages[@]}"
}

xorg__configure() {
  return 0
}
