# Global settings for software-installer.
#
# This file is sourced by modules/command.sh before any module runs.
# SCRIPT_DIR points to the directory containing installer.sh.
#
# Values use the ${VAR:-default} form, so they can also be overridden
# from the environment for a single run, for example:
#
#   CONFIG_DIR=/srv/dotfiles ./installer.sh -n zsh

# --- PATHS ---
# Directory with modules. Usually there is no reason to change it.
SOFTWARE_DIR="${SOFTWARE_DIR:-$SCRIPT_DIR/modules/software}"

# Directory with dotfiles configs copied by module__configure.
CONFIG_DIR="${CONFIG_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)/config}"

# Directory with local repository data (wallpapers, scripts, etc.).
LOCAL_DIR="${LOCAL_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)/local}"

# Directory with patches for programs
PATCHES_DIR="${PATCHES_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)/patches}"

# --- OUTPUT ---
# Color output: auto | always | never. Can also be set with --color.
UI_COLOR="${UI_COLOR:-auto}"

# --- APT ---
# Never ask questions during package installation. sudo resets the
# environment; lib__apt_run passes these values explicitly to apt/dpkg.
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

# --- PROMPTS ---
# Git must fail instead of asking for a username or password.
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"

# --- DOWNLOADS ---
# How many times to retry a failed download.
LIB_DOWNLOAD__ATTEMPTS="${LIB_DOWNLOAD__ATTEMPTS:-5}"

# wget timeouts, in seconds.
LIB_DOWNLOAD__CONNECT_TIMEOUT="${LIB_DOWNLOAD__CONNECT_TIMEOUT:-5}"
LIB_DOWNLOAD__READ_TIMEOUT="${LIB_DOWNLOAD__READ_TIMEOUT:-5}"

# Delay between download attempts, in seconds.
LIB_DOWNLOAD__BETWEEN_TIMEOUT="${LIB_DOWNLOAD__BETWEEN_TIMEOUT:-2}"


export SOFTWARE_DIR
export CONFIG_DIR
export LOCAL_DIR
