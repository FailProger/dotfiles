alacritty__get_build_dependencies() {
  local deps='
  rust
  git
  cmake
  make
  g++
  pkg-config
  libfontconfig1-dev
  libxcb-xfixes0-dev
  libxkbcommon-dev
  python3
  '
  echo "$deps"
}

alacritty__get_runtime_dependencies() {
  local deps='
  libfontconfig1
  libfreetype6
  libx11-6
  libxcb1
  libxcb-xfixes0
  libxcb-shape0
  libxcb-render0
  libxkbcommon0
  libxkbcommon-x11-0
  libwayland-client0
  '
  echo "$deps"
}

alacritty__install() {
  local workdir
  workdir="$(lib__tmpdir)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/alacritty/alacritty'
    cd alacritty

    export PATH="$HOME/.cargo/bin:$PATH"

    if ! command -v cargo > /dev/null 2>&1; then
      curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
    fi

    source "$HOME/.cargo/env"

    rustup override set stable
    rustup update stable

    cargo build --release
  )

  lib__install_binary "$tmp_dir/alacritty/target/release/alacritty" 'alacritty'
}

alacritty__configure() {
  lib__as_root update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$(command -v alacritty)" 100

  lib__cp_config 'alacritty'
}

alacritty__is_installed() {
  command -v alacritty > /dev/null 2>&1
}

alacritty__remove() {
  lib__as_root rm -f /usr/local/bin/alacritty
}

alacritty__deconfigure() {
  lib__as_root update-alternatives --remove x-terminal-emulator /usr/local/bin/alacritty 2> /dev/null || true
  rm -rf "$HOME/.config/alacritty"
}
