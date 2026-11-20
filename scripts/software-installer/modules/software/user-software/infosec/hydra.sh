hydra__get_build_dependencies() {
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

hydra__get_runtime_dependencies() {
  local deps='
  libssl3t64
  libssh-4
  libidn12
  libpcre2-8-0
  libmariadb3
  libpq5
  libsvn1
  libfbclient2
  libmemcached11t64
  libgcrypt20
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
