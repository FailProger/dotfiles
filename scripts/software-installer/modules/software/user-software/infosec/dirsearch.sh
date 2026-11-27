dirsearch__get_build_dependencies() {
  local deps='
  git
  python3-venv
  '
  echo "$deps"
}

dirsearch__get_runtime_dependencies() {
  local deps='
  python3
  ca-certificates
  '
  echo "$deps"
}

dirsearch__install() {
  local ds_dir='/opt/dirsearch'
  local workdir

  workdir="$(lib__tmpdir)"

  (
    cd "$workdir"

    git clone --depth 1 'https://github.com/maurosoria/dirsearch' 'dirsearch-src'
    cd dirsearch-src

    rm -rf .git .github .gitignore AGENTS.md CHANGELOG.md CONTRIBUTORS.md README.md docs tests testing.py

    python3 -m venv .venv
    ./.venv/bin/pip install -r requirements.txt
  )

  lib__as_root rm -rf "$ds_dir"
  lib__as_root mkdir -p /opt
  lib__as_root cp -rf "$workdir/dirsearch-src" "$ds_dir"
}

dirsearch__configure() {
  local ds_dir='/opt/dirsearch'
  local script_path='/usr/local/bin/dirsearch'

  lib__file_write "$script_path" 755 << EOF
#!/bin/sh

# It is a link to start dirsearch with python env.
$ds_dir/.venv/bin/python $ds_dir/dirsearch.py \$@
EOF
}

dirsearch__is_installed() {
  [[ -f /opt/dirsearch/dirsearch.py ]]
}

dirsearch__remove() {
  lib__as_root rm -rf /opt/dirsearch
}

dirsearch__deconfigure() {
  lib__as_root rm -f /usr/local/bin/dirsearch
}
