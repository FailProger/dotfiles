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
