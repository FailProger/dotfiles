metasploit__get_dependencies() {
  local deps='
  curl
  '
  echo "$deps"
}

metasploit__install() {
  local workdir
  local installer='msfupdate.erb'

  if command -v msfconsole > /dev/null 2>&1; then
    lib__log_info 'Metasploit is already installed, skipping.'
    return 0
  fi

  workdir="$(mktemp -d)"

  (
    cd "$workdir"
    lib__wget_download 'https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb'

    chmod 755 "$installer"
    lib__as_root "./$installer"
  )

  rm -rf "$workdir"
}

metasploit__configure() {
  return 0
}
