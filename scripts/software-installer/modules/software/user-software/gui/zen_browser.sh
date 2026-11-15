zen_browser__get_dependencies() {
  local deps='
  xz-utils
  '
  echo "$deps"
}

zen_browser__install() {
  lib__wget_download 'https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz'

  lib__as_root rm -rf /opt/zen /opt/zen_*
  lib__as_root mkdir -p /opt
  lib__as_root tar -xJf 'zen.linux-x86_64.tar.xz' -C /opt

  if [[ ! -d /opt/zen ]]; then
    lib__as_root mv /opt/zen* /opt/zen
  fi

  rm -f 'zen.linux-x86_64.tar.xz'
}

zen_browser__configure() {
  lib__as_root chmod 755 /opt/zen/zen
  lib__as_root ln -sf /opt/zen/zen /usr/local/bin/zen

  lib__file_write '/usr/local/share/applications/zen.desktop' 644 << EOF
[Desktop Entry]
Version=1.0
Name=Zen
Comment=Beautifully designed browser
GenericName=Web Browser
Keywords=Internet;WWW;Browser;Web;Explorer
Exec=zen
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=/opt/zen/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
StartupNotify=true
EOF
}
