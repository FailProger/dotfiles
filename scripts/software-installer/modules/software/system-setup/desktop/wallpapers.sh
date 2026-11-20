wallpapers__get_build_dependencies() {
  return 0
}

wallpapers__get_runtime_dependencies() {
  return 0
}

wallpapers__install() {
  return 0
}

wallpapers__configure() {
  local share_dir="$HOME/.local/share"
  local wp_dir="$share_dir/wallpapers"

  mkdir -p "$share_dir"

  rm -rf "$wp_dir"
  cp -r "$LOCAL_DIR/share/wallpapers" "$wp_dir"

  lib__file_write "$HOME/.fehbg" 700 << 'EOF'
#!/bin/sh
feh --no-fehbg --bg-fill "$HOME/.local/share/wallpapers/nothing2-21x9.png"
EOF

  find "$wp_dir" -type d -exec chmod 755 {} +
  find "$wp_dir" -type f -exec chmod 644 {} +
}
