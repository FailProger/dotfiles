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
