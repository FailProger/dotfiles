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
