# Global consts
# Defaults can be overridden in config.sh next to installer.sh.
: "${LIB_DOWNLOAD__ATTEMPTS:=5}"
: "${LIB_DOWNLOAD__CONNECT_TIMEOUT:=5}"
: "${LIB_DOWNLOAD__READ_TIMEOUT:=5}"
: "${LIB_DOWNLOAD__BETWEEN_TIMEOUT:=2}"

lib__wget_download() {
  local url="${1:?'Do not get url!'}"
  local output_document="${2:-}"

  if ! command -v wget > /dev/null 2>&1; then
    lib__apt_install wget
  fi

  local i

  if [[ -n "$output_document" ]]; then
    for (( i=0; i < "$LIB_DOWNLOAD__ATTEMPTS"; i++ )); do
        if wget \
          --connect-timeout="$LIB_DOWNLOAD__CONNECT_TIMEOUT" \
          --read-timeout="$LIB_DOWNLOAD__READ_TIMEOUT" -c "$url" \
          --output-document="$output_document" \
          ; then
          return 0
        fi

      sleep "$LIB_DOWNLOAD__BETWEEN_TIMEOUT"
    done
  else
    for (( i=0; i < "$LIB_DOWNLOAD__ATTEMPTS"; i++ )); do
        if wget \
          --connect-timeout="$LIB_DOWNLOAD__CONNECT_TIMEOUT" \
          --read-timeout="$LIB_DOWNLOAD__READ_TIMEOUT" -c "$url" \
          ; then
          return 0
        fi

      sleep "$LIB_DOWNLOAD__BETWEEN_TIMEOUT"
    done
  fi

  return 1
}

lib__wget_download_github_release() {
  local repo="${1:?'Do not get repo!'}"
  local file_name="${2:?'Do not get file name!'}"
  local output_document="${3:-}"

  local download_url

  if ! command -v wget > /dev/null 2>&1; then
    lib__apt_install wget
  fi

  local i

  for (( i=0; i < "$LIB_DOWNLOAD__ATTEMPTS"; i++ )); do
    download_url=$(
      wget -qO- --connect-timeout="$LIB_DOWNLOAD__CONNECT_TIMEOUT" --read-timeout="$LIB_DOWNLOAD__READ_TIMEOUT" "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' \
        | grep -m1 "$file_name"
    )

    if [[ -n "$download_url" ]]; then
      lib__wget_download "$download_url" "$output_document"
      return 0
    fi

    sleep "$LIB_DOWNLOAD__BETWEEN_TIMEOUT"
  done

  return 1
}
