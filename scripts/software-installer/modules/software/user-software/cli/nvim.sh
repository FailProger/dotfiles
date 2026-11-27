nvim__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

nvim__get_runtime_dependencies() {
  local deps='
  git
  '
  echo "$deps"
}

nvim__install() {
  local archive='nvim-linux-x86_64.tar.gz'
  local extracted_dir='/opt/nvim-linux-x86_64'

  lib__wget_download 'https://github.com/neovim/neovim/releases/download/v0.11.7/nvim-linux-x86_64.tar.gz'

  lib__as_root rm -rf /opt/nvim "$extracted_dir"
  lib__as_root mkdir -p /opt
  lib__as_root tar -xf "$archive" -C /opt
  lib__as_root mv "$extracted_dir" /opt/nvim
  lib__as_root ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  rm -f "$archive"
}

nvim__configure() {
  local config_dir="$HOME/.config/nvim"

  if [[ ! -f "$config_dir/init.lua" ]]; then
    rm -rf "$config_dir"
    git clone --depth 1 'https://github.com/AstroNvim/template' "$config_dir"
    rm -rf "$config_dir/.git" "$config_dir/README.md"
  fi

  cp -r "$CONFIG_DIR/nvim/." "$config_dir/"

  find "$config_dir" -type d -exec chmod 700 {} +
  find "$config_dir" -type f ! -perm -u+x -exec chmod 600 {} +
  find "$config_dir" -type f -perm -u+x -exec chmod 700 {} +
}

nvim__is_installed() {
  [[ -x /opt/nvim/bin/nvim ]]
}

nvim__remove() {
  lib__as_root rm -rf /opt/nvim
  lib__as_root rm -f /usr/local/bin/nvim
}

nvim__deconfigure() {
  rm -rf "$HOME/.config/nvim"
}
