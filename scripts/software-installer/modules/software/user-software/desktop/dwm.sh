dwm__get_build_dependencies() {
  local deps='
  git
  patch
  make
  gcc
  pkg-config
  libc6-dev
  libx11-dev
  libxfixes-dev
  libxi-dev
  libxinerama-dev
  libxft-dev
  libxrender-dev
  libimlib2-dev
  libxcb-util-dev
  '
  echo "$deps"
}

dwm__get_runtime_dependencies() {
  local deps='
  libx11-6
  libxfixes3
  libxi6
  libxinerama1
  libxft2
  libxrender1
  libimlib2t64
  libxcb1
  libxcb-util1
  '
  echo "$deps"
}

dwm__install() {
  local dwm_dir="$PATCHES_DIR/dwm"
  local workdir

  workdir="$(lib__tmpdir)"

  cd "$workdir"

  git clone --depth 1 'https://github.com/bakkeby/dwm-flexipatch'
  cd dwm-flexipatch

  patch -p1 < "$dwm_dir/dwm-flexipatch/my-patches.diff"
  cp patches.def.h patches.h
  patch -p1 < "$dwm_dir/dwm-flexipatch/patches.h.diff"
  cp "$dwm_dir/dwm-flexipatch/config.h" config.h

  cd ..

  git clone --depth 1 'https://github.com/bakkeby/flexipatch-finalizer'
  cd flexipatch-finalizer

  bash ./flexipatch-finalizer.sh -d ../dwm-flexipatch -o ../fin --run

  cd ../fin

  make
  lib__as_root make install

  cd ..

  git clone --depth 1 'https://github.com/UtkarshVerma/dwmblocks-async'
  cd dwmblocks-async

  cp "$dwm_dir/dwmblocks-async/config.h" config.h

  make
  lib__as_root make install
}

dwm__configure() {
  local bin_dir="$HOME/.local/bin"

  rm -rf "$bin_dir/statusbar"
  mkdir -p "$bin_dir"
  cp -r "$LOCAL_DIR/bin/statusbar" "$bin_dir"

  lib__cp_config 'X11/xinitrc' "$HOME/.xinitrc"
}

dwm__is_installed() {
  [[ -x /usr/local/bin/dwm && -x /usr/local/bin/dwmblocks ]]
}

dwm__remove() {
  lib__as_root rm -f /usr/local/bin/dwm /usr/local/bin/dwmblocks
  lib__as_root rm -f /usr/local/share/man/man1/dwm.1 /usr/local/share/man/man1/dwmblocks.1
}

dwm__deconfigure() {
  rm -rf "$HOME/.local/bin/statusbar"
}
