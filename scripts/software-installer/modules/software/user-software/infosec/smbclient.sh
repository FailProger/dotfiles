smbclient__get_dependencies() {
  return 0
}

smbclient__install() {
  lib__apt_install smbclient
}

smbclient__configure() {
  return 0
}
