metasploit__get_build_dependencies() {
  local deps='
  ca-certificates
  curl
  gpg
  '
  echo "$deps"
}

metasploit__get_runtime_dependencies() {
  return 0
}

metasploit__install() {
  local workdir

  workdir="$(lib__tmpdir)"

  (
    cd "$workdir"
    lib__wget_download 'https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb' 'msfupdate.erb'

    chmod 755 'msfupdate.erb'
    lib__as_root './msfupdate.erb'
  )
}

metasploit__configure() {
  return 0
}

metasploit__is_installed() {
  command -v msfconsole > /dev/null 2>&1
}

metasploit__remove() {
  lib__as_root rm -rf /opt/metasploit-framework
  lib__as_root rm -f /usr/local/bin/msfconsole /usr/local/bin/msfvenom /usr/local/bin/msfdb
}

metasploit__deconfigure() {
  return 0
}
