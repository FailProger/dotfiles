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

smbclient__is_installed() {
  lib__apt_is_installed smbclient
}

smbclient__remove() {
  lib__apt_remove smbclient
}

smbclient__deconfigure() {
  return 0
}
