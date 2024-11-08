#!/bin/sh
DATE=$(date "+%Y%m%d-%H%M%S")
export LD_LIBRARY_PATH=/home/pi/automeasure/brbox/output/lib

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

#1-initial triangle
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=3 --interval=5 $PSARG $TEMPARG --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/rgbw-begin.csv

#2-white measurement(keep the pattern fixed(loop 400=3hours)
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=400 --interval=20 $PSARG $TEMPARG --wfile=white.png --startupimg=white.png > /home/pi/automeasure/$DATE.csv

#3-initial triangle
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=3 --interval=5 $PSARG $TEMPARG --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/rgbw-end.csv

#4-at the end of the measurement, let the display cooldown
/home/pi/automeasure/brbox/output/bin/mplayclt --showimg=none


#/home/pi/automeasure/brbox/output/bin/mplayclt --showimg=none --showimg=/home/pi/automeasure/patterns/white.png
