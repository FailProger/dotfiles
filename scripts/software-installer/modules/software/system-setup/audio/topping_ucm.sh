topping_ucm__get_build_dependencies() {
  local deps='
  patch
  '
  echo "$deps"
}

topping_ucm__get_runtime_dependencies() {
  local deps='
  alsa-utils
  alsa-ucm-conf
  '
  echo "$deps"
}

topping_ucm__install() {
  return 0
}

topping_ucm__configure() {
  local ucm_dir='/usr/share/alsa/ucm2/USB-Audio'
  local conf_dir="$LOCAL_DIR/share/alsa/ucm2/USB-Audio"
  
  lib__as_root mkdir -p "$ucm_dir"

  lib__as_root rm -rf "$ucm_dir/Topping"
  lib__as_root cp -r "$conf_dir/Topping" "$ucm_dir/"

  lib__as_root patch -d "$ucm_dir" -p1 < "$conf_dir/USB-Audio.conf.diff"
}

topping_ucm__is_installed() {
  [[ -d /usr/share/alsa/ucm2/USB-Audio/Topping ]]
}

topping_ucm__remove() {
  return 0
}

topping_ucm__deconfigure() {
  lib__as_root rm -rf /usr/share/alsa/ucm2/USB-Audio/Topping
  lib__as_root patch -R -p1 -d /usr/share/alsa/ucm2/USB-Audio < "$LOCAL_DIR/share/alsa/ucm2/USB-Audio/USB-Audio.conf.diff" 2> /dev/null || true
}
