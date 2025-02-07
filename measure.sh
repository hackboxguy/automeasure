#!/bin/sh
# This script measures display colors by applying solid color patterns and measuring with a colorimeter.

# Exit on error
set -e

# Base configuration
MYPATH="/home/pi/automeasure"
PATTERNS="$MYPATH/patterns"              # Pattern directory - easily configurable
MEASUREMENTS_PATH="$MYPATH/Measurements"  # Base measurement directory
DATE=$(date "+%Y%m%d-%H%M%S")           # Timestamp for test directory
LOOPCOUNT=1                           # Measurements for 1 hour (120 samples @ 30sec/sample)
BEGIN_END_SAMPLES=3                     # Number of samples for initial and final measurements

# Set up library path
export LD_LIBRARY_PATH="$MYPATH/brbox/output/lib"

# Capture display info first
DISP_INFO=$(DISPLAY=:0 "$MYPATH/display_info.sh")
DATA_PREFIX=$(echo "$DISP_INFO" | awk '/CustomID/ {print $2}')
[ -z "$DATA_PREFIX" ] && DATA_PREFIX="Unknown"

# Create test-specific directory
TEST_DIR="$MEASUREMENTS_PATH/$DATE"
mkdir -p "$TEST_DIR"

# Save display info
echo "$DISP_INFO" > "$TEST_DIR/display-info.txt"

# File paths for measurements (simplified names as they're in their own directory)
BEGINFILE="$TEST_DIR/begin.csv"
DATAFILE="$TEST_DIR/data.csv"
ENDFILE="$TEST_DIR/end.csv"
BEGINFILE_FILTERED="$TEST_DIR/begin-filtered.csv"
ENDFILE_FILTERED="$TEST_DIR/end-filtered.csv"
GREYRAMPPATH="$TEST_DIR/grey-ramp.csv"
GREYRAMPPATH_FILTERED="$TEST_DIR/grey-ramp-filtered.csv"

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

# Common arguments for measure-color.sh
COMMON_ARGS="--mypath=$MYPATH --patternpath=$PATTERNS $PSARG $TEMPARG"

# Cold Measurements (Initial)
echo "Taking initial RGB measurements..."
"$MYPATH/measure-color.sh" $COMMON_ARGS \
    --loop="$BEGIN_END_SAMPLES" \
    --interval=5 \
    --wfile=white.png \
    --rfile=red.png \
    --gfile=green.png \
    --bfile=blue.png > "$BEGINFILE"

# White Measurement (Long-Term)
echo "Starting long-term white measurements..."
"$MYPATH/measure-color.sh" $COMMON_ARGS \
    --loop="$LOOPCOUNT" \
    --interval=20 \
    --wfile=white.png \
    --startupimg=white.png > "$DATAFILE"

# Warm Measurements (Final)
echo "Taking final RGB measurements..."
"$MYPATH/measure-color.sh" $COMMON_ARGS \
    --loop="$BEGIN_END_SAMPLES" \
    --interval=5 \
    --wfile=white.png \
    --rfile=red.png \
    --gfile=green.png \
    --bfile=blue.png > "$ENDFILE"

# Measure Grey-Ramp
# Print CSV header(pass --noheader=yes to measure-color.sh)
PATTERNS="$MYPATH/patterns/greyramp-patterns"
COMMON_ARGS="--mypath=$MYPATH --patternpath=$PATTERNS $PSARG $TEMPARG"
echo "DATE,TIME,temp,Sampled-Color,X,Y,Z,Y,x,y,voltage,current,brightnesslevel" > $GREYRAMPPATH
i=0
for i in 0 13 26 38 51 64 77 89 102 115 128 140 153 166 179 191 204 217 230 255; do
        RAMPFILE="grey_${i}.png"
        "$MYPATH/measure-color.sh" $COMMON_ARGS \
                --loop=1 \
                --noheader=yes \
                --interval=1 \
                --wfile="$RAMPFILE" \
                --brlevel="$i" >> "$GREYRAMPPATH"
done

# Let the display cool down
echo "Measurement complete. Turning off display pattern..."
"$MYPATH/brbox/output/bin/mplayclt" --showimg=none

#lets filter the data(take only xyY of rgbw of both begin and end csv files)
"$MYPATH/filter-wrgb-data.sh" --input="$BEGINFILE" --output="$BEGINFILE_FILTERED"
"$MYPATH/filter-wrgb-data.sh" --input="$ENDFILE" --output="$ENDFILE_FILTERED"
"$MYPATH/filter-greyramp-data.sh" --input="$GREYRAMPPATH" --output="$GREYRAMPPATH_FILTERED"

echo "Test results saved in: $TEST_DIR"
echo "Files:"
echo "  Display Info: display-info.txt"
echo "  Begin:        begin.csv"
echo "  Data:         data.csv"
echo "  End:          end.csv"
echo "  GreyRamp:     grey-ramp.csv"
