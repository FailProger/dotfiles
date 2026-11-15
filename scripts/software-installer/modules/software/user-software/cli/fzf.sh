fzf__get_dependencies() {
  return 0
}

fzf__install() {
  lib__wget_download_github_release 'junegunn/fzf' 'fzf-.*-linux_amd64.tar.gz'
  lib__mv_to_local_bin 'fzf'
}

fzf__configure() {
  return 0
}
