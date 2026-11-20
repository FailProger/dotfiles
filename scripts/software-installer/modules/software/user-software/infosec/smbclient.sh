smbclient__get_build_dependencies() {
  return 0
}

smbclient__get_runtime_dependencies() {
  return 0
}

smbclient__install() {
  lib__apt_install smbclient
}

smbclient__configure() {
  return 0
}
