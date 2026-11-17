opencode__get_dependencies() {
  return 0
}

opencode__install() {
  local arch

  case "$(dpkg --print-architecture)" in
    amd64)
      arch='x64'
      ;;
    arm64)
      arch='arm64'
      ;;
    *)
      lib__log_error "Unsupported architecture for OpenCode: $(dpkg --print-architecture)"
      return 1
      ;;
  esac

  # Install the standalone V2 binary to /usr/local/bin. This does not edit
  # any shell file and does not add an export PATH line.
  local url="https://opencode.ai/update/api/latest/cli/opencode/opencode-linux-${arch}.tar.gz"

  lib__wget_download "$url"
  lib__mv_to_local_bin 'opencode'
}

opencode__configure() {
  return 0
}
