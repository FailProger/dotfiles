cli_utils__get_build_dependencies() {
  return 0
}

cli_utils__get_runtime_dependencies() {
  return 0
}

cli_utils__install() {
  local -a packages=(
    wget
    curl
    openssh-client
    zip
    unzip
    7zip
    gzip
    xz-utils
    zstd
  )

  lib__apt_install "${packages[@]}"
}

cli_utils__configure() {
  return 0
}

cli_utils__is_installed() {
  lib__apt_is_installed curl && lib__apt_is_installed wget
}

cli_utils__remove() {
  lib__apt_remove wget curl openssh-client zip unzip 7zip gzip xz-utils zstd
}

cli_utils__deconfigure() {
  return 0
}
