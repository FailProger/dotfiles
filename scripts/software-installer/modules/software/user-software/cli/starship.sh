starship__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

starship__get_runtime_dependencies() {
  return 0
}

starship__install() {
  lib__wget_download 'https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz'
  lib__mv_to_local_bin 'starship'
}

starship__configure() {
  local config_dir="$HOME/.config/starship"

  mkdir -p "$config_dir"
  /usr/local/bin/starship preset 'jetpack' -o "$config_dir/starship.toml"
}
