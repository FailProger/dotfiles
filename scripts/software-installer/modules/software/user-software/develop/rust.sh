rust__get_dependencies() {
  local deps='
  curl
  ca-certificates
  gcc
  libc6-dev
  '
  echo "$deps"
}

rust__install() {
  /usr/bin/bash -s << 'EOF'
curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
EOF
}

rust__configure() {
  return 0
}
