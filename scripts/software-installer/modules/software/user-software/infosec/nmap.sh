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

  workdir="$(lib__tmpdir)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/nmap/nmap'
    cd nmap

    ./configure
    make
    lib__as_root make install
  )
}

nmap__configure() {
  lib__as_root update-alternatives --install /usr/bin/nc nc /usr/local/bin/ncat 100
  lib__as_root update-alternatives --install /usr/bin/ping ping /usr/local/bin/nping 100
}

nmap__is_installed() {
  command -v nmap > /dev/null 2>&1
}

nmap__remove() {
  lib__as_root rm -f /usr/local/bin/nmap /usr/local/bin/ncat /usr/local/bin/nping
}

nmap__deconfigure() {
  lib__as_root update-alternatives --remove nc /usr/local/bin/ncat 2> /dev/null || true
  lib__as_root update-alternatives --remove ping /usr/local/bin/nping 2> /dev/null || true
}
