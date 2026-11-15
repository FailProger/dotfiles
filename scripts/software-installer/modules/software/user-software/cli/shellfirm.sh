shellfirm__get_dependencies() {
  return 0
}

shellfirm__install() {
  lib__wget_download_github_release 'kaplanelad/shellfirm' 'shellfirm-.*-x86_64-linux.tar.xz'
  lib__mv_to_local_bin 'shellfirm'
}

shellfirm__configure() {
  lib__cp_config 'shellfirm'
}
