alacritty__get_dependencies() {
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

alacritty__install() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  /usr/bin/bash -s -- "$tmp_dir" << 'EOF'
set -e

cd "$1"
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
EOF

  lib__install_binary "$tmp_dir/alacritty/target/release/alacritty" 'alacritty'
  lib__as_root rm -rf "$tmp_dir"
}

alacritty__configure() {
  lib__as_root update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$(command -v alacritty)" 100

  lib__cp_config 'alacritty'
}
