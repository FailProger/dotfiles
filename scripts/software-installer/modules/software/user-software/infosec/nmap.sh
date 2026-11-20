nmap__get_build_dependencies() {
  local deps='
  git
  g++
  make
  libc6-dev
  libssl-dev
  '
  echo "$deps"
}

nmap__get_runtime_dependencies() {
  local deps='
  libssl3t64
  libpcap0.8t64
  '
  echo "$deps"
}

nmap__install() {
  local workdir

  workdir="$(mktemp -d)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/nmap/nmap'
    cd nmap

    ./configure
    make
    lib__as_root make install
  )

  rm -rf "$workdir"
}

nmap__configure() {
  return 0
}
