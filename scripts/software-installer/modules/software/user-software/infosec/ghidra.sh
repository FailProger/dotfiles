ghidra__get_dependencies() {
  local deps='
  unzip
  openjdk-25-jdk
  '
  echo "$deps"
}

ghidra__install() {
  local extracted_dir

  lib__wget_download_github_release 'NationalSecurityAgency/ghidra' 'ghidra_.*_PUBLIC_.*.zip'

  lib__as_root rm -rf /opt/ghidra /opt/ghidra_*
  lib__as_root mkdir -p /opt
  lib__as_root unzip -o ghidra*.zip -d /opt

  extracted_dir="$(find /opt -maxdepth 1 -type d -name 'ghidra_*' -print -quit)"
  if [[ -z "$extracted_dir" ]]; then
    lib__log_error 'Ghidra archive did not contain the expected directory.'
    return 1
  fi

  lib__as_root mv "$extracted_dir" /opt/ghidra

  rm -f ghidra*.zip
}

ghidra__configure() {
  lib__as_root chmod 755 /opt/ghidra/ghidraRun
  lib__as_root ln -sf /opt/ghidra/ghidraRun /usr/local/bin/ghidra

  lib__file_write '/usr/local/share/applications/ghidra.desktop' 644 << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Ghidra
GenericName=Reverse Engineering Tool
Comment=Software Reverse Engineering (SRE) suite
Exec=ghidra
Icon=/opt/ghidra/support/ghidra.ico
Terminal=false
Categories=Development;Security;
StartupNotify=true
EOF
}
