#!/bin/sh
# Display volume levels.

wpctl() {
    arg="$2"

    set -- "$1"
    if [ "$1" = set-volume ]; then
        set -- "$@" --limit=1.0
    fi

    set -- "$@" @DEFAULT_AUDIO_SINK@ "$arg"

    command wpctl "$@"
}

if wpctl get-volume | grep -q "[MUTED]"; then
    . "$(dirname "$0")/theme.sh"
    display " " 9
    exit
fi

volume="$(wpctl get-volume | awk '{print int($2 * 100)}')"

if [ -z "$volume" ]; then
    exit 1
fi

if [ "$volume" -gt 40 ]; then
    icon=""
elif [ "$volume" -gt 15 ]; then
    icon=""
else
    icon=""
fi

. "$(dirname "$0")/theme.sh"
display "$icon ${volume}%"
