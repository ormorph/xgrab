#!/usr/bin/env bash

#sets the processing command
source $GRAB_COMMAND

# Directory where to save the file
OUTDIR="$HOME/screenshot"

if ! [ -d "$OUTDIR" ] ; then
	mkdir -p "$OUTDIR"
fi

#Defines the current screen resolution:
while read file
do
	MASS=($file)
	if [ -n "$(echo ${MASS[1]}|egrep '\*\+')" ] ; then
		SCR_SIZE="${MASS[0]}"
	fi
done <<<"$(xrandr --current)" 

#Generated random a name
NAME="$(tr -cd [:digit:] < /dev/urandom | head -c8)"
FILE="VID_$NAME"


OPT_GRAB="$(cat $FILE_SET|sed '1!D')"
OPT_CHECK1="$(cat $FILE_SET|sed '2!D')"
OPT_SOUND="$(cat $FILE_SET|sed '3!D')"
OPT_DISPL="$(cat $FILE_SET|sed '4!D')"
OPT_DEC="$(cat $FILE_COMP|sed '1!D')"
OPT_CHECK2="$(cat $FILE_COMP|sed '2!D')"


#Option x11 grab. Sound - pactl list short sources
if [ $OPT_DISPL = "size" ] ; then
	sleep 0.5s
	INFO_DISP="$(xrectsel)"
	SCR_SIZE=$(echo $INFO_DISP | grep -oE '[0-9]+x[0-9]+')
	WIN_XY=$(echo $INFO_DISP | grep -oE '\+[0-9]+\+[0-9]+' | grep -oE '[0-9]+\+[0-9]+'|tr "+" ",")
	TARGET_WIDTH=$(echo ${SCR_SIZE//x/ } | awk '{print $1}')
	TARGET_WIDTH="${TARGET_WIDTH%[0-9]}0"
	TARGET_HEIGHT=$(echo ${SCR_SIZE//x/ } | awk '{print $2}')
	TARGET_HEIGHT="${TARGET_HEIGHT%[0-9]}0"

        OPT_DISP="$DISPLAY+$WIN_XY"
elif [ $OPT_DISPL = "window" ] ; then
	sleep 0.5s
	INFO_DISP="$(xwininfo|grep geometry)"
	SCR_SIZE=$(echo $INFO_DISP | grep -oE '[0-9]+x[0-9]+')
	WIN_XY=$(echo $INFO_DISP | egrep -oE '\+[0-9]+\+[0-9]+' | grep -oE '[0-9]+\+[0-9]+'|tr "+" ",")
        TARGET_WIDTH=$(echo ${SCR_SIZE//x/ } | awk '{print $1}')
        TARGET_WIDTH="${TARGET_WIDTH%[0-9]}0"
        TARGET_HEIGHT=$(echo ${SCR_SIZE//x/ } | awk '{print $2}')
        TARGET_HEIGHT="${TARGET_HEIGHT%[0-9]}0"

        OPT_DISP="$DISPLAY+$WIN_XY"
else 
        TARGET_WIDTH=$(echo ${SCR_SIZE//x/ } | awk '{print $1}')
        TARGET_WIDTH="${TARGET_WIDTH%[0-9]}0"
        TARGET_HEIGHT=$(echo ${SCR_SIZE//x/ } | awk '{print $2}')
        TARGET_HEIGHT="${TARGET_HEIGHT%[0-9]}0"

	OPT_DISP=$DISPLAY
fi

OPT_DEC="${OPT_DEC//TARGET_WIDTH/$TARGET_WIDTH}"
OPT_DEC="${OPT_DEC//TARGET_HEIGHT/$TARGET_HEIGHT}"

if [ "$OPT_CHECK1" = "TRUE" ] ; then 
        OPTION_GRAB="$OPT_SOUND ${OPT_GRAB//\$SCR_SIZE/$SCR_SIZE}"
	OPTION_GRAB="${OPTION_GRAB//\$DISPLAY/$OPT_DISP}"
else
        OPTION_GRAB="${OPT_GRAB//\$SCR_SIZE/$SCR_SIZE}"
	OPTION_GRAB="${OPTION_GRAB//\$DISPLAY/$OPT_DISP}"
fi

# the command grabbing video
$COMMAND $OPTION_GRAB $OUTDIR/$NAME.mp4 >/dev/null 2>&1 &

# running process pid
PID="$!"
echo $PID >$PIPE.pid
sleep 1s

while true
do
  if ! pidof $COMMAND|grep $PID >/dev/null ;then
  break
  fi
  sleep 0.2s
done

rm $PIPE.pid

COMMAND_COMP="$COMMAND -i $OUTDIR/$NAME.mp4 $OPT_DEC  $OUTDIR/$FILE.mp4"

CONV(){
	$COMMAND_COMP 2>&1 |stdbuf -o0 tr '\r' '\n' | while read file
	do
		MASS=($file)

	    if  [ -n "$(echo ${MASS[0]}|egrep Duration)" ] ; then 
		    DURATION="${MASS[1]:0:8}"
	    fi

	    if [ -n "$(echo "$file"|egrep "time=")" ] ; then
		TIME="$(echo $file | egrep -oE  '+[0-9]+:+[0-9]+:+[0-9][0-9]')"
		echo "# The compression process takes $DURATION"
                echo "# The compression process takes $DURATION"

                HMS1=(${DURATION//:/ })
		HMS2=(${TIME//:/ })

		#Remove the first zero
		HMS1=(${HMS1[@]#0})
		HMS2=(${HMS2[@]#0})

		#calculation percentage
                SEK1=$((${HMS1[0]}*3600+${HMS1[1]}*60+${HMS1[2]}))
                SEK2=$((${HMS2[0]}*3600+${HMS2[1]}*60+${HMS2[2]}))
                PERCENT=$(($SEK2*100/$SEK1))
                echo "$(($PERCENT))"
	    fi
	done 
}

# avconv stream processing function
CONV2(){
	$COMMAND_COMP  2>&1| stdbuf -o0 tr '\r' '\n' | while read file
	do
		MASS=($file)

		if  [ -n "$(echo ${MASS[0]}|egrep Duration)" ] ; then 
		DURATION="${MASS[1]:0:8}"
		echo "# The compression process takes $DURATION"
                echo "# The compression process takes $DURATION"
	    fi

	    if [ -n "$(echo "$file"|egrep "time=")" ] ; then
		TIME=$(echo $file | egrep -oE 'time=+[0-9]+'|egrep -oE '[0-9]+')

                HMS1=(${DURATION//:/ })

		#Remove the first zero
		HMS1=(${HMS1[@]#0})

		#calculation percentage
                SEK1=$((${HMS1[0]}*3600+${HMS1[1]}*60+${HMS1[2]}))
                PERCENT=$(($TIME*100/$SEK1))
                echo "$(($PERCENT))"
	    fi
	done 
}


# yad dialogue function
process(){
	if [ "$COMMAND" = "ffmpeg" ] ; then
	    CONV
        elif [ "$COMMAND" = "avconv" ] ; then
            CONV2
        fi
	echo "# Compression completed!"
	echo "100"
}

if [ "$OPT_CHECK2" = "TRUE" ] ; then 
	process|yad --progress \
	--auto-close \
	--title="videofile processing" \
	--text="Compression process start" \
	--percentage=0
	rm $OUTDIR/$NAME.mp4
fi
