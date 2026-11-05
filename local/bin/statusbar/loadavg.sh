#!/bin/sh
# Display the average CPU load.

load=$(cut -d ' ' -f1 /proc/loadavg | xargs)

. "$(dirname "$0")/theme.sh"
display " $load"
