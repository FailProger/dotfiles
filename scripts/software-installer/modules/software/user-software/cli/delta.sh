delta__get_dependencies() {
  return 0
}

delta__install() {
  rm -f ./git-delta_*_amd64.deb

  lib__wget_download_github_release 'dandavison/delta' 'git-delta_.*_amd64.deb'
  lib__apt_install ./git-delta_*_amd64.deb
  rm -f ./git-delta_*_amd64.deb
}

delta__configure() {
  return 0
}
