#!/usr/bin/env bash

# create a FIFO file, used to manage the I/O redirection from shell
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)

# Ad of global variables
export DIR="$HOME/.xgrab"
export SETTING_F="xgrab.conf"
export COMPRESS_F="xcomp.conf"
export FILE_SET="$DIR/$SETTING_F"
export FILE_COMP="$DIR/$COMPRESS_F"
export PIPE
export GRAB_COMMAND="./command"

#configuration files Install
if [ ! -d $DIR ] ; then
    mkdir $DIR
fi

if [ ! -f $FILE_SET ] ; then
    cp $SETTING_F $FILE_SET
fi

if [ ! -f $FILE_COMP ] ; then
    cp $COMPRESS_F $FILE_COMP
fi

mkfifo $PIPE

# attach a file descriptor to the file
exec 3<> $PIPE

# add handler to manage process shutdown
on_exit() {
    exec 3<> $PIPE
    echo "quit" >&3

    if [ -f $PIPE.pid ] ;  then
       kill $(cat $PIPE.pid)
    fi

    rm -f $PIPE
}


# add handler for tray icon left click
on_click() {
    exec 3<> $PIPE
    ./grab.sh &
    echo "icon:icon/start.png" >&3
    echo "action:bash -c on_click2" >&3
    echo "tooltip:Stop x11 grabing"  >&3
}

# add handler for tray icon left click
on_click2() {
    exec 3<> $PIPE
    kill $(cat $PIPE.pid)
    echo "icon:icon/stop.png" >&3
    echo "action:bash -c on_click" >&3
    echo "tooltip:Start x11 grabing"  >&3
}

# start settings dialog
on_setting() {

    if ipcs|grep 0x00003039 >/dev/null ; then
        ipcrm -M 0x00003039
    fi

    OPT_S1="$(cat $FILE_SET|sed '1!D')"
    OPT_S2="$(cat $FILE_SET|sed '2!D')"
    OPT_S3="$(cat $FILE_SET|sed '3!D')"
    OPT_C1="$(cat $FILE_COMP|sed '1!D')"
    OPT_C2="$(cat $FILE_COMP|sed '2!D')"

    yad --plug=12345 --tabnum=1 --form --text="Video capture options" \
    --field "options video" --field sound:chk --field \
    "options sound" "'$OPT_S1'"  "$OPT_S2" "'$OPT_S3'" | \
    tr "|" "\n" | sed "s/'//g" &>$FILE_SET.tmp &

    yad --plug=12345 --tabnum=2 --form --text="Options compress" --field \
    "" --field compress:chk "'$OPT_C1'" "$OPT_C2" | tr "|" "\n" | \
    sed "s/'//g" &>$FILE_COMP.tmp &

    yad --title="Settings" --notebook --key=12345 --tab="X11 grab" --tab="Compress"

    if [ $? -eq 0 ] ; then
        cp $FILE_COMP.tmp $FILE_COMP
        cp $FILE_SET.tmp $FILE_SET
        rm $FILE_COMP.tmp
        rm $FILE_SET.tmp
    else 
        rm $FILE_COMP.tmp
        rm $FILE_SET.tmp
    fi
}

# Ad of global functions
export -f on_exit
export -f on_click2
export -f on_click
export -f on_setting

# create the notification icon
yad --notification \
    --kill-parent \
    --listen \
    --image="icon/stop.png" \
    --text="Start x11 grabing" \
    --command="bash -c on_click" <&3 &

# create the trayicon menu
echo "menu: $(cat menufile | tr '\n' '|' | sed '$s/.$//')" >&3

