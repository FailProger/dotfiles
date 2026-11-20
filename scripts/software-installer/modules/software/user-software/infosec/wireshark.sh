wireshark__get_build_dependencies() {
  return 0
}

wireshark__get_runtime_dependencies() {
  return 0
}

wireshark__install() {
  lib__apt_install wireshark
}

wireshark__configure() {
  echo 'wireshark-common wireshark-common/install-setuid boolean true' | lib__apt_run debconf-set-selections
  lib__apt_run dpkg-reconfigure -f noninteractive wireshark-common

  lib__as_root usermod -aG wireshark "$USER"
}
