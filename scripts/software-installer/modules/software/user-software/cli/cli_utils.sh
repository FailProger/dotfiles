cli_utils__get_dependencies() {
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
