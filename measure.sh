#!/bin/sh
DATE=$(date "+%Y%m%d-%H%M%S")
/home/pi/automeasure/measure-color.sh --loop=100 --interval=10 --tempered=tempered --wfile=white.png --rfile=red.png --gfile=green.png --bfile=blue.png > /home/pi/automeasure/$DATE.csv
