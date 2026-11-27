ltrace_strace__get_build_dependencies() {
  return 0
}

ltrace_strace__get_runtime_dependencies() {
  return 0
}

ltrace_strace__install() {
  lib__apt_install ltrace strace
}

ltrace_strace__configure() {
  return 0
}

ltrace_strace__is_installed() {
  lib__apt_is_installed ltrace && lib__apt_is_installed strace
}

ltrace_strace__remove() {
  lib__apt_remove ltrace strace
}

ltrace_strace__deconfigure() {
  return 0
}
