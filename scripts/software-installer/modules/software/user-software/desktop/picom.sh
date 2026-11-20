# picom is built from source: the release in the distribution repositories is
# too old for the current configuration. PICOM_VERSION can pin a release tag;
# by default the latest stable tag is used.
#
# libconfig >= 1.7 is required. When the distribution ships an older version,
# meson builds a static copy from the bundled subproject, which is why cmake is
# a build dependency and old distributions do not need a libconfig runtime
# package.

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

# Latest stable release tag. Version tags look like v13 or v12.5; anything
# else (vNext, v13-rc1) is rejected by the pattern.
_picom__latest_release_tag() {
  local repo="${1:?'Do not get repo!'}"

  git ls-remote --tags --refs --sort=-v:refname "$repo" 2> /dev/null \
    | awk -F '\t' '{ sub(/^refs\/tags\//, "", $2); print $2 }' \
    | grep -E '^v[0-9]+(\.[0-9]+)*$' \
    | head -n 1
}

picom__install() {
  local repo='https://github.com/yshui/picom.git'
  local prefix='/usr/local'
  local tag="${PICOM_VERSION:-}"
  local had_binary=0
  local workdir

  if lib__apt_is_installed picom; then
    lib__log_warn 'The apt package picom is installed as well; /usr/local/bin/picom built here takes precedence.'
  fi

  if [[ -e "$prefix/bin/picom" ]]; then
    had_binary=1
  fi

  if [[ -z "$tag" ]]; then
    tag="$(_picom__latest_release_tag "$repo")"
  fi

  if [[ -z "$tag" ]]; then
    lib__log_error 'Cannot resolve the picom release tag to build.'
    return 1
  fi

  lib__log_info "Building picom $tag from source."

  workdir="$(mktemp -d)"

  if ! (
    cd "$workdir" || exit 1

    git clone --depth 1 --branch "$tag" "$repo" picom || exit 1
    cd picom || exit 1

    meson setup \
      --buildtype=release \
      --prefix="$prefix" \
      -Dstrip=true \
      -Dcompton=false \
      build || exit 1

    ninja -C build || exit 1
    lib__as_root ninja -C build install || exit 1
  ); then
    lib__log_error "Failed to build picom $tag."
    rm -rf "$workdir"
    return 1
  fi

  rm -rf "$workdir"

  if [[ "$had_binary" -eq 0 ]]; then
    lib__state_mark_owned
  fi
}

picom__configure() {
  lib__cp_config 'picom'
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

  if ! lib__state_is_owned; then
    lib__log_info 'picom was not installed by this installer; keeping it.'
    lib__state_mark_kept
    return 0
  fi

  lib__as_root rm -f "${files[@]}"
  lib__as_root rmdir --ignore-fail-on-non-empty '/usr/local/include/picom' 2> /dev/null || true

  lib__log_info 'Removed picom built from source.'
}
