picom__get_build_dependencies() {
  local deps='
  ca-certificates
  cmake
  git
  meson
  ninja-build
  pkg-config
  gcc
  g++
  libc6-dev
  libconfig-dev
  libdbus-1-dev
  libegl-dev
  libev-dev
  libgl-dev
  libepoxy-dev
  libpcre2-dev
  libpixman-1-dev
  libx11-dev
  libx11-xcb-dev
  libxcb1-dev
  libxcb-composite0-dev
  libxcb-damage0-dev
  libxcb-glx0-dev
  libxcb-image0-dev
  libxcb-present-dev
  libxcb-randr0-dev
  libxcb-render0-dev
  libxcb-render-util0-dev
  libxcb-shape0-dev
  libxcb-sync-dev
  libxcb-util-dev
  libxcb-xfixes0-dev
  libxext-dev
  uthash-dev
  '
  echo "$deps"
}

picom__get_runtime_dependencies() {
  local deps='
  libdbus-1-3
  libegl1
  libev4t64
  libgl1
  libepoxy0
  libpcre2-8-0
  libpixman-1-0
  libx11-6
  libx11-xcb1
  libxcb1
  libxcb-composite0
  libxcb-damage0
  libxcb-glx0
  libxcb-image0
  libxcb-present0
  libxcb-randr0
  libxcb-render0
  libxcb-render-util0
  libxcb-shape0
  libxcb-sync1
  libxcb-util1
  libxcb-xfixes0
  libxext6
  '
  echo "$deps"
}

picom__install() {
  local repo=${PICOM_REPO:-'https://github.com/pijulius/picom'}
  local branch="${PICOM_BRANCH:-'next'}"
  local prefix='/usr/local'

  local picom_dir="$PATCHES_DIR/picom"
  local workdir

  workdir="$(lib__tmpdir)"

  cd "$workdir"

  git clone --depth 1 --branch "$branch" "$repo" picom
  cd picom

  patch -p1 < "$picom_dir/my-patches.diff"
  cp "$picom_dir/animation_presets.conf" data/animation_presets.conf

  meson setup \
    --buildtype=release \
    --prefix="$prefix" \
    -Dstrip=true \
    -Dcompton=false \
    build
  meson compile -C build animgen
  ./build/tools/animgen data/animation_presets.conf > src/transition/generated/script_templates.c

  ninja -C build
  lib__as_root ninja -C build install
}

picom__configure() {
  lib__cp_config 'picom'
}

picom__is_installed() {
  command -v picom > /dev/null 2>&1
}

picom__remove() {
  local -a files=(
    '/usr/local/bin/picom'
    '/usr/local/bin/picom-inspect'
    '/usr/local/bin/picom-trans'
    '/usr/local/include/picom/api.h'
    '/usr/local/include/picom/backend.h'
    '/usr/local/share/applications/picom.desktop'
    '/usr/local/lib/pkgconfig/picom-api.pc'
    '/usr/local/lib/x86_64-linux-gnu/pkgconfig/picom-api.pc'
    '/usr/local/lib64/pkgconfig/picom-api.pc'
  )

  lib__as_root rm -f "${files[@]}"
  lib__as_root rmdir --ignore-fail-on-non-empty '/usr/local/include/picom' 2> /dev/null || true
}

picom__deconfigure() {
  rm -rf "$HOME/.config/picom"
}
