hydra__get_dependencies() {
  local deps='
  git
  gcc
  make
  libc6-dev
  libssl-dev
  libssh-dev
  libidn11-dev
  libpcre2-dev
  libmysqlclient-dev
  libpq-dev
  libsvn-dev
  firebird-dev
  libmemcached-dev
  libgcrypt20-dev
  '
  echo "$deps"
}

hydra__install() {
  local workdir

  workdir="$(mktemp -d)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/vanhauser-thc/thc-hydra'
    cd thc-hydra

    ./configure
    make
    lib__as_root make install
  )

  rm -rf "$workdir"
}

hydra__configure() {
  return 0
}
