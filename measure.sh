#!/bin/sh
DATE=$(date "+%Y%m%d-%H%M%S")
export LD_LIBRARY_PATH=/home/pi/automeasure/brbox/output/lib

#RGBW measurement
#/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=10 --tempered=tempered --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/$DATE.csv

#white measurement(keep the pattern fixed
/home/pi/automeasure/brbox/output/bin/mplayclt --showimg=none --showimg=/home/pi/automeasure/patterns/white.png
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=20 --tempered=tempered --wfile=white.png --startupimg=white.png --measureonly=yes > /home/pi/automeasure/$DATE.csv
