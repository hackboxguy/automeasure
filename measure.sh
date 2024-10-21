#!/bin/sh
DATE=$(date "+%Y%m%d-%H%M%S")
export LD_LIBRARY_PATH=/home/pi/automeasure/brbox/output/lib

#RGBW measurement
#/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=10 --tempered=tempered --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/$DATE.csv

#check if ka3005p power supply is available
/home/pi/automeasure/binaries/ka3005p status > /dev/null
if [ $? = 0 ]; then
	PSARG="--power=ka3005p"
else
	PSARG=""
fi

sudo /home/pi/automeasure/Output/usb-tempered/utils/tempered 1> /dev/null 2>/dev/null
if [ $? = 0 ]; then
	TEMPARG="--temp=tempered"
else
	TEMPARG=""
fi

#white measurement(keep the pattern fixed
/home/pi/automeasure/brbox/output/bin/mplayclt --showimg=none --showimg=/home/pi/automeasure/patterns/white.png
#/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=20 --power=ka3005p --tempered=tempered --wfile=white.png --startupimg=white.png --measureonly=yes > /home/pi/automeasure/$DATE.csv
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=20 $PSARG $TEMPARG --wfile=white.png --startupimg=white.png --measureonly=yes > /home/pi/automeasure/$DATE.csv
