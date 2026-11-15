# --- COLORS ---
# Primary colors
color1='#1c1c1c'
color2='#bc5653'
color3='#909d63'
color4='#ebc17a'
color5='#7eaac7'
color6='#aa6292'
color7='#70c0b1'
color8='#cacaca'

# --- FUNCTIONS ---
display() {
    local value=${1:?'Do not get value to display!'}
    local color_number=${2:-}

    if [ -z "$color_number" ]; then
        case "$(basename "$0")" in
            disk.sh) color_number=3 ;;
            memory.sh) color_number=8 ;;
            loadavg.sh) color_number=4 ;;
            volume.sh) color_number=8 ;;
            date.sh) color_number=5 ;;
            *) color_number=8 ;;
        esac
    fi

    case "$color_number" in
        1) color=$color1 ;;
        2) color=$color2 ;;
        3) color=$color3 ;;
        4) color=$color4 ;;
        5) color=$color5 ;;
        6) color=$color6 ;;
        7) color=$color7 ;;
        8) color=$color8 ;;
        *) color=$color8 ;;
    esac

    echo "^c${color}^${value}^d^"
}
