dwm__get_dependencies() {
  # Build requirements from the flexipatch configuration:
  # X11, Xinerama, Xft, Xrender (alpha), Imlib2 (winicon), and xcb-atom
  # plus pkg-config for dwmblocks-async.
  local deps='
  xorg
  dmenu
  fonts
  git
  patch
  make
  gcc
  pkg-config
  libc6-dev
  libx11-dev
  libxinerama-dev
  libxft-dev
  libxrender-dev
  libimlib2-dev
  libxcb-util-dev
  i3lock
  xss-lock
  '
  echo "$deps"
}

dwm__install() {
  local dwm_dir="$(cd -- "$SCRIPT_DIR/../../suckless/dwm" && pwd)"
  local workdir="$(mktemp -d)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/bakkeby/dwm-flexipatch'
    cd dwm-flexipatch

    patch -p1 < "$dwm_dir/dwm-flexipatch/my-patches.diff"
    cp patches.def.h patches.h
    patch -p1 < "$dwm_dir/dwm-flexipatch/patches.h.diff"
    cp "$dwm_dir/dwm-flexipatch/config-laptop.h" config.h

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
  )

  rm -rf "$workdir"
}

dwm__configure() {
  local bin_dir="$HOME/.local/bin"

  rm -rf "$bin_dir/statusbar"
  mkdir -p "$bin_dir"
  cp -r "$LOCAL_DIR/bin/statusbar" "$bin_dir"
}
