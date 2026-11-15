#!/bin/sh
# Display the current time in HH:MM.

format='+%H:%M:%S'
datetime=$(date "$format")

. "$(dirname "$0")/theme.sh"
display "󰥔 ${datetime} "
