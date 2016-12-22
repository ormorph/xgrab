#!/bin/bash

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
OPT_DEC="$(cat $FILE_COMP|sed '1!D')"
OPT_CHECK2="$(cat $FILE_COMP|sed '2!D')"

#Option x11 grab. Sound - pactl list short sources
if [ "$OPT_CHECK1" = "TRUE" ] ; then 
        OPTION_GRAB="$OPT_SOUND ${OPT_GRAB//\$SCR_SIZE/$SCR_SIZE}"
else
        OPTION_GRAB="${OPT_GRAB//\$SCR_SIZE/$SCR_SIZE}"
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

# ffmpeg stream processing function
CONV(){
	$COMMAND -i "$OUTDIR/$NAME.mp4" $OPT_DEC \
	"$OUTDIR/$FILE.mp4" 2>&1 | stdbuf -o0 tr \
	'\r' '\n'|while read file
	do
		MASS=(${file//fps=/fps= })

	    if  [ -n "$(echo ${MASS[0]}|egrep Duration)" ] ; then 
		    DURATION="${MASS[1]:0:8}"
	    fi

	    if [ -n "$(echo "$file"|egrep "time=")" ] ; then
		TIME="${MASS[7]:5:8}"
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
	$COMMAND -i "$OUTDIR/$NAME.mp4" -acodec libmp3lame \
	-ab 128k -ac 2 -vcodec libx264 -crf 22 -threads 0 \
	"$OUTDIR/$FILE.mp4" 2>&1| stdbuf -o0 tr \
	'\r' '\n'|while read file
	do
		file=${file//./ }
		MASS=($file)

		if  [ -n "$(echo ${MASS[0]}|egrep Duration)" ] ; then 
		DURATION="${MASS[1]:0:8}"
		echo "# The compression process takes $DURATION"
                echo "# The compression process takes $DURATION"
	    fi

	    if [ -n "$(echo "$file"|egrep "time=")" ] ; then
		TIME="${MASS[8]:5}"

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
