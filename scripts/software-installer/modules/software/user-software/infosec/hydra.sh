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

  workdir="$(lib__tmpdir)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/vanhauser-thc/thc-hydra'
    cd thc-hydra

    ./configure
    make
    lib__as_root make install
  )
}

hydra__configure() {
  return 0
}

hydra__is_installed() {
  command -v hydra > /dev/null 2>&1
}

hydra__remove() {
  lib__as_root rm -f /usr/local/bin/hydra /usr/local/bin/xhydra /usr/local/bin/pw-inspector /usr/local/bin/dpl4hydra
  lib__as_root rm -f /usr/local/share/man/man1/hydra.1 /usr/local/share/man/man1/xhydra.1
}

hydra__deconfigure() {
  return 0
}
