# Global settings for software-installer.
#
# This file is sourced by modules/command.sh before any module runs.
# SCRIPT_DIR points to the directory containing installer.sh.
#
# Values use the ${VAR:-default} form, so they can also be overridden
# from the environment for a single run, for example:
#
#   DOTFILES_DIR=/srv/dotfiles ./installer.sh -n zsh

# --- PATHS ---
# Directory with modules. Usually there is no reason to change it.
SOFTWARE_DIR="${SOFTWARE_DIR:-$SCRIPT_DIR/modules/software}"

# Directory with dotfiles configs copied by module__configure.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)/config}"

# Directory with local repository data (wallpapers, scripts, etc.).
LOCAL_DIR="${LOCAL_DIR:-$(cd -- "$SCRIPT_DIR/../.." && pwd)/local}"

# --- OUTPUT ---
# Color output: auto | always | never. Can also be set with --color.
UI_COLOR="${UI_COLOR:-auto}"

# --- APT ---
# Never ask questions during package installation.
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

# --- DOWNLOADS ---
# How many times to retry a failed download.
LIB_DOWNLOAD__ATTEMPTS="${LIB_DOWNLOAD__ATTEMPTS:-5}"

# wget timeouts, in seconds.
LIB_DOWNLOAD__CONNECT_TIMEOUT="${LIB_DOWNLOAD__CONNECT_TIMEOUT:-5}"
LIB_DOWNLOAD__READ_TIMEOUT="${LIB_DOWNLOAD__READ_TIMEOUT:-5}"

# Delay between download attempts, in seconds.
LIB_DOWNLOAD__BETWEEN_TIMEOUT="${LIB_DOWNLOAD__BETWEEN_TIMEOUT:-2}"


export SOFTWARE_DIR
export DOTFILES_DIR
export LOCAL_DIR
