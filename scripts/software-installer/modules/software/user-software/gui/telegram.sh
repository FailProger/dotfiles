telegram__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  xz-utils
  '
  echo "$deps"
}

telegram__get_runtime_dependencies() {
  return 0
}

telegram__install() {
  local tg_dir='/opt/telegram'
  local extracted_dir='/opt/Telegram'

  lib__wget_download 'https://telegram.org/dl/desktop/linux' 'telegram.tar.xz'

  lib__as_root rm -rf "$tg_dir" "$extracted_dir"
  lib__as_root mkdir -p /opt
  lib__as_root tar -xvf 'telegram.tar.xz' -C /opt

  if [[ ! -d "$extracted_dir" ]]; then
    lib__log_error 'Telegram archive did not contain the expected directory.'
    return 1
  fi

  lib__as_root mv "$extracted_dir" "$tg_dir"
  lib__as_root chown -R root:root "$tg_dir"

  lib__as_root ln -sf "$tg_dir/Telegram" /usr/local/bin/telegram

  rm -f 'telegram.tar.xz'
}

telegram__configure() {
  return 0
}

telegram__is_installed() {
  [[ -x /opt/telegram/Telegram ]]
}

telegram__remove() {
  lib__as_root rm -rf /opt/telegram
  lib__as_root rm -f /usr/local/bin/telegram
}

telegram__deconfigure() {
  return 0
}
