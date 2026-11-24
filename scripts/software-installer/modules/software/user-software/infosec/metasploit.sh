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
  if command -v msfconsole > /dev/null 2>&1; then
    lib__log_info 'Metasploit is already installed, skipping.'
    return 0
  fi

  local workdir="$(mktemp -d)"

  (
    cd "$workdir"
    lib__wget_download 'https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb' 'msfupdate.erb'

    chmod 755 'msfupdate.erb'
    lib__as_root './msfupdate.erb'
  )

  rm -rf "$workdir"
}

metasploit__configure() {
  return 0
}
