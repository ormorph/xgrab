if which ffmpeg 2>/dev/null >/dev/null; then
   COMMAND="ffmpeg"
fi

if which avconv 2>/dev/null >/dev/null ; then
   COMMAND="avconv"
fi
