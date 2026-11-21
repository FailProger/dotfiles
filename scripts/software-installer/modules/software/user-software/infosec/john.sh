john__get_build_dependencies() {
  local deps='
  git
  gcc
  make
  libc6-dev
  libssl-dev
  libgmp-dev
  zlib1g-dev
  libbz2-dev
  '
  echo "$deps"
}

john__get_runtime_dependencies() {
  local deps='
  libssl3t64
  libgmp10
  zlib1g
  libbz2-1.0
  '
  echo "$deps"
}

john__install() {
  local workdir
  local john_dir='/opt/john-the-ripper'

  workdir="$(mktemp -d)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/openwall/john'
    cd john/src

    ./configure
    make -s clean
    make -sj4
  )

  lib__as_root rm -rf "$john_dir"
  lib__as_root mkdir -p /opt
  lib__as_root cp -rf "$workdir/john/run" "$john_dir"

  rm -rf "$workdir"
}

john__configure() {
  local john_dir='/opt/john-the-ripper'
  local script_path='/usr/local/bin/john'

  lib__file_write "$script_path" 755 << EOF
#!/bin/sh

# It is a link to origin john the ripper,
# need to start john with full path.
$john_dir/john \$@
EOF

  # John the Ripper is not installed to PATH by upstream.
  if [[ ! -f "$HOME/.zsh_custom" ]] || ! grep -q '/opt/john-the-ripper' "$HOME/.zsh_custom"; then
    echo "Please add $john_dir to PATH in your shell rc file."
  fi
}
