discord__get_build_dependencies() {
  local deps='
  ca-certificates
  wget
  '
  echo "$deps"
}

discord__get_runtime_dependencies() {
  return 0
}

discord__install() {
  rm -f ./discord.deb

  lib__wget_download 'https://discordapp.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=linux&arch=x64' 'discord.deb'
  lib__apt_install ./discord.deb

  rm -f ./discord.deb
}

discord__configure() {
  return 0
}
