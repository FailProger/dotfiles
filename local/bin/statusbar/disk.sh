#!/bin/sh
# Display disk usage for both `/`.

path='/'

used="$(df --output=used -h "$path" | tail -n 1 | xargs)"

percent_used="$(df --output=pcent "$path" | tail -n 1 | grep -o '[[:digit:]]\+')"
[ "$percent_used" -ge 90 ] && color=9

. "$(dirname "$0")/theme.sh"
display "  󰋊 ${used}iB" "$color"
