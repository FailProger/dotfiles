sddm__get_build_dependencies() {
  return 0
}

sddm__get_runtime_dependencies() {
  return 0
}

sddm__install() {
  lib__apt_install sddm
}

sddm__configure() {
  local dm_dir='/etc/sddm.conf.d'

  lib__as_root mkdir -p "$dm_dir"

  lib__file_write "$dm_dir/autologin.conf" 644 << EOF
[Autologin]
User=$USER
Session=i3
EOF
}

sddm__is_installed() {
  lib__apt_is_installed sddm
}

sddm__remove() {
  lib__apt_remove sddm
}

sddm__deconfigure() {
  lib__as_root rm -f /etc/sddm.conf.d/autologin.conf
}
