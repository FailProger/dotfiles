seclists__get_build_dependencies() {
  local deps='
  git
  '
  echo "$deps"
}

seclists__get_runtime_dependencies() {
  return 0
}

seclists__install() {
  local seclists_dir='/usr/local/share/seclists'

  # A partial or interrupted clone leaves a directory without the expected
  # content; recreate it instead of skipping forever.
  if [[ ! -d "$seclists_dir/Passwords" ]]; then
    lib__as_root rm -rf "$seclists_dir"
    lib__as_root mkdir -p /usr/local/share
    lib__as_root git clone --depth 1 'https://github.com/danielmiessler/SecLists' "$seclists_dir"
  fi
}

seclists__configure() {
  local wordlists_dir='/usr/local/share/wordlists'
  local seclists_dir='/usr/local/share/seclists'
  local leaked_db_dir="$seclists_dir/Passwords/Leaked-Databases"

  lib__as_root rm -rf "$seclists_dir/LICENSE" \
    "$seclists_dir/CONTRIBUTING.md" \
    "$seclists_dir/CONTRIBUTORS.md" \
    "$seclists_dir/funding.json" \
    "$seclists_dir/.git" \
    "$seclists_dir/.github" \
    "$seclists_dir/.bin"

  if [[ -f "$leaked_db_dir/rockyou.txt.tar.gz" ]]; then
    lib__as_root tar -xf "$leaked_db_dir/rockyou.txt.tar.gz" -C "$leaked_db_dir"
    lib__as_root rm -f "$leaked_db_dir/rockyou.txt.tar.gz"
  fi

  if [[ -f "$leaked_db_dir/rockyou.txt" ]]; then
    lib__as_root chmod 644 "$leaked_db_dir/rockyou.txt"
    lib__as_root mkdir -p "$wordlists_dir"
    lib__as_root ln -sf "$leaked_db_dir/rockyou.txt" "$wordlists_dir/rockyou.txt"
  else
    lib__log_warn "rockyou.txt not found at $leaked_db_dir."
  fi
}

seclists__is_installed() {
  [[ -d /usr/local/share/seclists/Passwords ]]
}

seclists__remove() {
  lib__as_root rm -rf /usr/local/share/seclists
}

seclists__deconfigure() {
  lib__as_root rm -f /usr/local/share/wordlists/rockyou.txt
}
