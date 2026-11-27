fonts__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  unzip
  '
  echo "$deps"
}

fonts__get_runtime_dependencies() {
  local deps='
  fontconfig
  '
  echo "$deps"
}

fonts__install() {
  local nerd_fonts_dir='/usr/local/share/fonts/hack-nerd-font/'

  lib__as_root mkdir -p "$nerd_fonts_dir"
  lib__wget_download 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip'
  lib__as_root unzip -o 'Hack.zip' -d "$nerd_fonts_dir"

  rm -f 'Hack.zip'
  lib__as_root rm -f "$nerd_fonts_dir/LICENSE.md" "$nerd_fonts_dir/README.md"

  lib__as_root find "$nerd_fonts_dir" -type d -exec chmod 755 {} +
  lib__as_root find "$nerd_fonts_dir" -type f -exec chmod 644 {} +

  lib__as_root fc-cache -f
}

fonts__configure() {
  return 0
}

fonts__is_installed() {
  [[ -d /usr/local/share/fonts/hack-nerd-font ]]
}

fonts__remove() {
  lib__as_root rm -rf /usr/local/share/fonts/hack-nerd-font
  lib__as_root fc-cache -f
}

fonts__deconfigure() {
  return 0
}
