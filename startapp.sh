#!/bin/sh
kill $(cat /tmp/statweb.pid)
export >/tmp/exports
DANCER_APPDIR=$PWD
echo Starting app:
#bin/app.pl --port=3001
screen -fn -dmS statweb script -a -c "bin/app.pl --port=3001" /tmp/statweb.log
