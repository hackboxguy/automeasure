#!/bin/sh
DATE=$(date "+%Y%m%d-%H%M%S")
export LD_LIBRARY_PATH=/home/pi/automeasure/brbox/output/lib
/home/pi/automeasure/measure-color.sh --mypath=/home/pi/automeasure --loop=8000 --interval=20 --tempered=tempered --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/$DATE.csv
