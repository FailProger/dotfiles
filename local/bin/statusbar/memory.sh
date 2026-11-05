#!/bin/sh
# Display RAM usage.

used="$(free -h | grep '^Mem:' | tr -s ' ' | cut -d ' ' -f3 | xargs)"

. "$(dirname "$0")/theme.sh"
display " ${used}B"
