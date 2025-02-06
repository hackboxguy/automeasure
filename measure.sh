#!/bin/sh

# This script measures display colors by applying solid color patterns and measuring with a colorimeter.

set -e  # Exit on error

MYPATH="/home/pi/automeasure"
PATTERNS="$MYPATH/patterns"
MEASUREMENTS_PATH="$MYPATH/Measurements"
DATE=$(date "+%Y%m%d-%H%M%S")
LOOPCOUNT=100
BEGIN_END_SAMPLES=3  # Number of samples for initial and final measurements
export LD_LIBRARY_PATH="$MYPATH/brbox/output/lib"

# Ensure the Measurements directory exists
mkdir -p "$MEASUREMENTS_PATH"

# Check if KA3005P power supply is available
if "$MYPATH/binaries/ka3005p" status > /dev/null 2>&1; then
    PSARG="--power=ka3005p"
else
    PSARG=""
fi

# Check if USB-Tempered temperature sensor is available
if sudo "$MYPATH/Output/usb-tempered/utils/tempered" > /dev/null 2>&1; then
    TEMPARG="--temp=tempered"
else
    TEMPARG=""
fi

# Capture display info
DISP_INFO_FILE="$MYPATH/display-info.txt"
"$MYPATH/display_info.sh" > "$DISP_INFO_FILE"

# Extract CustomID from display info
DATA_PREFIX=$(awk '/CustomID/ {print $2}' "$DISP_INFO_FILE")
[ -z "$DATA_PREFIX" ] && DATA_PREFIX="Unknown"

# Ensure DATA variable is set
DATA="$DATE"

# File paths for measurements
BEGINFILE="$MEASUREMENTS_PATH/${DATA_PREFIX}-${DATA}-begin.csv"
DATAFILE="$MEASUREMENTS_PATH/${DATA_PREFIX}-${DATA}-data.csv"
ENDFILE="$MEASUREMENTS_PATH/${DATA_PREFIX}-${DATA}-end.csv"

# Cold Measurements (Initial)
"$MYPATH/measure-color.sh" --mypath="$MYPATH" --loop="$BEGIN_END_SAMPLES" --interval=5 $PSARG $TEMPARG \
    --wfile=white.png --rfile=red.png \
    --gfile=green.png --bfile=blue.png > "$BEGINFILE"

# White Measurement (Long-Term, 3 Hours)
"$MYPATH/measure-color.sh" --mypath="$MYPATH" --loop="$LOOPCOUNT" --interval=20 $PSARG $TEMPARG \
    --wfile=white.png --startupimg=white.png > "$DATAFILE"

# Warm Measurements (Final)
"$MYPATH/measure-color.sh" --mypath="$MYPATH" --loop="$BEGIN_END_SAMPLES" --interval=5 $PSARG $TEMPARG \
    --wfile=white.png --rfile=red.png \
    --gfile=green.png --bfile=blue.png > "$ENDFILE"

# Let the display cool down
"$MYPATH/brbox/output/bin/mplayclt" --showimg=none

