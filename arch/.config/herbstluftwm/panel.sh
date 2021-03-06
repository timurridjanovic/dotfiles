#!/bin/bash

hc() {
	"${herbstclient_command[@]:-herbstclient}" "$@" ;
}

dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$dir/theme.sh"
source "$dir/panel_indicators.sh"

monitor=${1:-0}

geometry=( $(herbstclient monitor_rect "$monitor") )
if [ -z "$geometry" ] ;then
    echo "Invalid monitor $monitor"
    exit 1
fi
# geometry has the format W H X Y
x=$(echo "${geometry[0]} + $bar_x_p" | bc)
y=$(echo "${geometry[1]} + $bar_y_p" | bc)
panel_width=$(echo "${geometry[2]} - (2 * $bar_x_p)" | bc)
bar_opts="-g ${panel_width}x${panel_h}+${x}+${y} -f $font,$font_sec -u 2 -B $acolor_bg -F $acolor_fg"

hc pad $monitor $(echo "$panel_h + $bar_y_p" | bc)

uniq_linebuffered() {
    awk '$0 != l { print ; l=$0 ; fflush(); }' "$@"
}

{
    while true ; do
		music
		volume
		network
		battery
		clock
        sleep 1 || break
    done | (uniq_linebuffered) &
    childpid=$!
    hc --idle
    kill $childpid
} 2> /dev/null | {

    IFS=$'\t' read -ra tags <<< "$(hc tag_status $monitor)"
    visible=true
    date=""
    volume=""
    battery=""
    net=""
    windowtitle=""
    while true ; do
        separator="%{F$acolor_accent}|%{F-}"
        # draw tags
        for i in "${tags[@]}" ; do
            case ${i:0:1} in
                # viewed on active monitor
                '#')
                    echo -n "%{B$acolor_accent}%{F$acolor_fg}"
                    ;;
                # viewed on inactive monitor
                '+')
                    echo -n "%{U$acolor_fg+u}%{F$acolor_fg}"
                    ;;
                # tag is not empty
                ':')
                    echo -n "%{F$acolor_fg}"
                    ;;
                # tag is urgent
                '!')
                    echo -n "%{B$acolor_accent}%{U$acolor_accent+u}%{F$acolor_bg}"
                    ;;
                '.')
                    echo -n "%{F$acolor_empty}"
                    ;;
                # default
                *)
                    echo -n "%{F$acolor_fg}"
                    ;;
            esac
            echo -n "%{A:tag,${i:1}:} ${i:1} %{A}%{F-}%{U-u}%{B-}"
        done
        echo -n "$separator%{F-}%{B-} "
        echo -n "${windowtitle//^/^^}"

		#Right part of panel
        right="$music$volume$net$battery$date "
        echo -n "%{r}$right"

		#DO NOT REMOVE THIS ECHO
		echo

        # wait for next event
        IFS=$'\t' read -ra cmd || break
        case "${cmd[0]}" in
            tag*)
                #echo "resetting tags" >&2
                IFS=$'\t' read -ra tags <<< "$(hc tag_status $monitor)"
                ;;
			music)
				music="${cmd[@]:1}"
				if [ $music == "off" ] ; then
					music=""
				else
					music="$music $separator%{B-} "
				fi
				;;
			volume)
				volume="${cmd[@]:1}"
				if [ $volume == "off" ] ; then
					volume=""
				else
					volume="$volume $separator%{B-} "
				fi
				;;
			net)
				net="${cmd[@]:1}"
				if [ $net = "off" ] ; then
					net=""
				else
					net="$net $separator%{B-} "
				fi
				;;
			battery)
				battery="${cmd[@]:1}"
				if [ $battery == "off" ] ; then
					battery=""
				else
					battery="$battery $separator%{B-} "
				fi
				;;
            date)
                #echo "resetting date" >&2
                date="${cmd[@]:1}"
                ;;
            focus_changed|window_title_changed)
                windowtitle="${cmd[@]:2}"
                ;;
        esac
    done
} 2> /dev/null | lemonbar $bar_opts | {
	#Handle clickable areas
	while read line; do
		IFS=',' read -a c <<< $(echo $line)
		case "${c[0]}" in
			tag)
				herbstclient use "${c[1]}"
				echo "herbstclient use \"${c[1]}\""
				;;
			*)
				echo "${c[0]}: not valid command"
				;;
		esac
	done
}
