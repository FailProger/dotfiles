enum4linux__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

enum4linux__get_runtime_dependencies() {
  local deps='
  perl
  smbclient
  '
  echo "$deps"
}

enum4linux__install() {
  lib__wget_download 'https://raw.githubusercontent.com/CiscoCXSecurity/enum4linux/master/enum4linux.pl'

  lib__install_binary 'enum4linux.pl' 'enum4linux'
  rm -f 'enum4linux.pl'
}

enum4linux__configure() {
  return 0
}

enum4linux__is_installed() {
  command -v enum4linux > /dev/null 2>&1
}

enum4linux__remove() {
  lib__as_root rm -f /usr/local/bin/enum4linux
}

enum4linux__deconfigure() {
  return 0
}
