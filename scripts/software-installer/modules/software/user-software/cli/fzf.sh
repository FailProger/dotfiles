fzf__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

fzf__get_runtime_dependencies() {
  return 0
}

fzf__install() {
  lib__wget_download_github_release 'junegunn/fzf' 'fzf-.*-linux_amd64.tar.gz'
  lib__mv_to_local_bin 'fzf'
}

fzf__configure() {
  return 0
}

fzf__is_installed() {
  command -v fzf > /dev/null 2>&1
}

fzf__remove() {
  lib__as_root rm -f /usr/local/bin/fzf
}

fzf__deconfigure() {
  return 0
}
