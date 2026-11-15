dirsearch__get_dependencies() {
  local deps='
  git
  python3-venv
  '
  echo "$deps"
}

dirsearch__install() {
  local ds_dir='/opt/dirsearch'
  local workdir

  workdir="$(mktemp -d)"

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
  lib__as_root mv "$workdir/dirsearch-src" "$ds_dir"

  rm -rf "$workdir"
}

dirsearch__configure() {
  local ds_dir='/opt/dirsearch'
  local script_path='/usr/local/bin/dirsearch'

  lib__file_write "$script_path" 755 << EOF
#!/usr/bin/env bash

# It is a link to start dirsearch with python env.
$ds_dir/.venv/bin/python $ds_dir/dirsearch.py \$@
EOF
}
