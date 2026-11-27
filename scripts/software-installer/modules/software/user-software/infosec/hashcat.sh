hashcat__get_build_dependencies() {
  return 0
}

hashcat__get_runtime_dependencies() {
  return 0
}

hashcat__install() {
  lib__apt_install hashcat
}

hashcat__configure() {
  return 0
}

hashcat__is_installed() {
  lib__apt_is_installed hashcat
}

hashcat__remove() {
  lib__apt_remove hashcat
}

hashcat__deconfigure() {
  return 0
}
