topping_ucm__get_dependencies() {
  local deps='
  alsa-utils
  alsa-ucm-conf
  patch
  '
  echo "$deps"
}

topping_ucm__install() {
  return 0
}

topping_ucm__configure() {
  local work_dir='/usr/share/alsa/ucm2/USB-Audio'
  local conf_dir="$CONFIG_DIR/alsa/ucm2/USB-Audio"
  
  lib__as_root mkdir -p "$work_dir"
  lib__as_root rm -rf "$work_dir/Topping"

  (
    cd "$work_dir"

    lib__as_root patch -p1 < "$conf_dir/USB-Audio.conf.diff"
    lib__as_root cp -r "$conf_dir/Topping" .
  )
}
