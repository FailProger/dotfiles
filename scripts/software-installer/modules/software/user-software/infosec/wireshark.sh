wireshark__get_dependencies() {
  return 0
}

wireshark__install() {
  lib__apt_install wireshark
}

wireshark__configure() {
  echo 'wireshark-common wireshark-common/install-setuid boolean true' | lib__as_root debconf-set-selections
  lib__as_root dpkg-reconfigure -f noninteractive wireshark-common

  lib__as_root usermod -aG wireshark "$USER"
}
