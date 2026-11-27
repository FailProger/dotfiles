docker__get_build_dependencies() {
  local deps='
  curl
  gnupg
  '
  echo "$deps"
}

docker__get_runtime_dependencies() {
  # The Docker repository stays in apt sources, so HTTPS must keep working.
  local deps='
  ca-certificates
  '
  echo "$deps"
}

docker__install() {
  local repo_distro
  local codename
  local arch
  local key_url
  local keyring='/etc/apt/keyrings/docker.gpg'
  local tmp_key

  if lib__apt_is_installed 'docker.io'; then
    lib__log_error 'docker.io is installed; remove it before installing docker-ce.'
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  case " ${ID:-} ${ID_LIKE:-} " in
    *ubuntu*)
      repo_distro='ubuntu'
      ;;
    *debian*)
      repo_distro='debian'
      ;;
    *)
      lib__log_error "Unsupported distribution for Docker: ${ID:-unknown}"
      return 1
      ;;
  esac

  if [[ "$repo_distro" == 'ubuntu' ]]; then
    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  else
    codename="${VERSION_CODENAME:-}"
  fi

  if [[ -z "$codename" ]]; then
    lib__log_error 'Cannot detect distribution codename.'
    return 1
  fi

  arch="$(dpkg --print-architecture)"
  key_url="https://download.docker.com/linux/${repo_distro}/gpg"

  lib__as_root install -d -m 0755 /etc/apt/keyrings

  tmp_key="$(mktemp)"
  if ! curl -fsSL "$key_url" -o "$tmp_key"; then
    rm -f "$tmp_key"
    lib__log_error 'Failed to download the Docker signing key.'
    return 1
  fi

  if ! lib__as_root gpg --dearmor --yes -o "$keyring" "$tmp_key"; then
    rm -f "$tmp_key"
    lib__log_error 'Failed to install the Docker signing key.'
    return 1
  fi

  rm -f "$tmp_key"
  lib__as_root chmod 644 "$keyring"

  lib__file_write '/etc/apt/sources.list.d/docker.list' 644 << EOF
deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/${repo_distro} ${codename} stable
EOF

  lib__apt_update --force
  lib__apt_install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
}

docker__configure() {
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx 'docker'; then
    lib__as_root usermod -aG docker "$USER"
    lib__log_info "Added $USER to the docker group; log out and in again."
  fi

  lib__as_root systemctl enable --now docker
}

docker__is_installed() {
  lib__apt_is_installed docker-ce
}

docker__remove() {
  lib__as_root rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
  lib__apt_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

docker__deconfigure() {
  lib__as_root systemctl disable --now docker 2> /dev/null || true
  lib__as_root gpasswd -d "$USER" docker 2> /dev/null || true
}
