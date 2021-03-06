#!/bin/bash
#
# usage:
#
# html2pdf.sh <html inputfile> <pdf outputfile> [<logfile>] [<wkhtmltopdf binary>]
#

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
  exec >>$LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
WKHTMLTOPDF=$4

[ -z $WKHTMLTOPDF ] && WKHTMLTOPDF="wkhtmltopdf"

EXTRAOPTIONS='-q'

DISP=$RANDOM
let "DISP %= 500"
while [ -f /tmp/.X${DISP}-lock ];do
  DISP=$RANDOM
  let "DISP %= 500";
done;
XAUTHORITY=`mktemp`;
TMPLOG=`mktemp`;
Xvfb -screen 0 1024x768x24 -dpi 60 -terminate -auth $XAUTHORITY -nolisten tcp :$DISP >$TMPLOG 2>&1 &
xpid=$!

# wait for xauth
for x in seq 10; do
    sleep 1;
    [ -e $XAUTHORITY ] && break;
done

# wait x-lock
for x in seq 5; do
    sleep 1;
    [ -e /tmp/.X${DISP}-lock ] && break;
done

if [ ! -e /tmp/.X${DISP}-lock -o ! -e $XAUTHORITY ]; then
    echo "xvfb failed to start"
    cat $TMPLOG
    exit 1
fi

rm -f $OUTPUT
DISPLAY=:$DISP $WKHTMLTOPDF \
        --use-xserver \
        -l \
        $WKHTMLTOPDFOPTIONS \
        $EXTRAOPTIONS \
        --image-quality 100 \
        --disable-smart-shrinking \
        -s A4 \
        -B 0mm -L 0mm -R 0mm -T 0mm \
        "$INPUT" "$OUTPUT" 2>&1 | \
    grep -v 'QPixmap: Cannot create a QPixmap when no GUI is being used'

[ -e "$OUTPUT" ] || cat $TMPLOG

# ensure file is not owned by root
if [ -e "$OUTPUT" -a $UID == 0 ]; then
    usr=`ls -la "$INPUT" | awk '{ print $3 }'`
    grp=`ls -la "$INPUT" | awk '{ print $4 }'`
    chown $usr:$grp $OUTPUT
fi

kill $xpid >/dev/null 2>&1
rm -f $TMPLOG $XAUTHORITY /tmp/.X${DISP}-lock
