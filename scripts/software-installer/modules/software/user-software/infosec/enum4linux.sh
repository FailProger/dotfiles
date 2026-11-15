enum4linux__get_dependencies() {
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
