#!/bin/sh
kill $(cat /tmp/statweb.pid)
export >/tmp/exports
echo Starting app:
screen -fn -dmS statweb bin/app.pl --port=3001
