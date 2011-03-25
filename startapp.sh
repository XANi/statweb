#!/bin/sh
kill $(cat /tmp/statweb.pid);
screen -fn -dmS statweb bin/app.pl
