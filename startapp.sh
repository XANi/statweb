#!/bin/sh
kill $(cat /tmp/statweb.pid) 2>/dev/null
DANCER_APPDIR=$PWD
export >/tmp/statweb.env
screen -fn -dmS statweb script -a -c "bin/app.pl --port=3001" /tmp/statweb.log
