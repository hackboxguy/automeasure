#!/bin/sh
# Color Measurement Script for Display Analysis
# Dependencies: argyll, mpv packages

# Default configuration
LOOPCOUNT="1"
INTERVAL="none"
TEMPERED="none"
POWER="none"
WFILE="none"
RFILE="none"
GFILE="none"
BFILE="none"
CFILE="none"
MFILE="none"
YFILE="none"
STARTUPIMG="none"
MEASUREONLY="no"
BRLEVEL="100"
NOHEADER="no"
MYPATH="$(pwd)"
PATTERNPATH="$MYPATH/patterns"  # Default pattern path

# Constants
MAX_RETRIES=3
RETRY_DELAY=5
MEASUREMENT_DELAY=5

# Usage information
USAGE="usage: $0 
    --mypath=/automes/path 
    --patternpath=/path/to/patterns
    --measureonly=yes/no
    --loop=count 
    --noheader=yes/no
    --interval=seconds 
    --startupimg=white 
    --temp=/path/to/tempered 
    --power=/path/to/powermeas 
    --wfile=/pathto/w.png 
    --rfile=/pathto/r.png 
    --gfile=/pathto/g.png 
    --bfile=/pathto/b.png
    --cfile=/pathto/c.png 
    --mfile=/pathto/m.png 
    --yfile=/pathto/y.png 
    --brlevel=brightness_level"
NOARGS="yes"

# Function to log errors
log_error() {
    echo "ERROR: $*" >&2
}

# Function to log information
log_info() {
    echo "INFO: $*"
}

# Check required commands
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "Required command '$1' not found"
        return 1
    }
}

# Measure color values with retries
measure_color() {
    pattern_file="$1"
    color_prefix="$2"
    tempered_path="$3"
    startup_pattern="$4"
    mplayclt_path="$5"
    power_path="$6"
    br_level="$7"
    
    # Display pattern if startup_pattern is none (meaning we change for each measurement)
    if [ "$startup_pattern" = "none" ]; then
        $mplayclt_path --showimg=none --showimg="$pattern_file" > /dev/null
        sleep 5
    fi

    # Get timestamp
    DATE=$(date "+%D,%T")

    # Measure temperature if sensor available
    if [ "$tempered_path" != "none" ]; then
        TEMP=$(sudo $tempered_path | awk '{print $4}' 2>/dev/null || echo "ERROR")
    else
        TEMP="N/A"
    fi
    
    # Measure power if available
    if [ "$power_path" != "none" ]; then
        TMPPOWER=$($power_path status)
        VOLTAGE=$(echo $TMPPOWER | awk '{print $2}')
        CURRENT=$(echo $TMPPOWER | awk '{print $5}')
    else
        VOLTAGE="N/A"
        CURRENT="N/A"
    fi

    # Color measurement with retries
    retry=1
    while [ $retry -le $MAX_RETRIES ]; do
        VAL=$(sudo spotread -x -O | grep Result | sed 's/ Result is //' | sed 's/XYZ://' | sed 's/Yxy://' | sed 's/,//')
        WORDS=$(echo "$VAL" | wc -c)
        
        if [ $WORDS -gt 1 ]; then
            break
        fi
        
        if [ $retry -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
        retry=$((retry + 1))
    done

    # Parse color values
    if [ $WORDS -gt 1 ]; then
        XVAL=$(echo $VAL | awk '{print $1}')
        YVAL=$(echo $VAL | awk '{print $2}')
        ZVAL=$(echo $VAL | awk '{print $3}')
        YCVAL=$(echo $VAL | awk '{print $4}')
        xVAL=$(echo $VAL | awk '{print $5}')
        yVAL=$(echo $VAL | awk '{print $6}')
        echo "$DATE,$TEMP,$color_prefix,$XVAL,$YVAL,$ZVAL,$YCVAL,$xVAL,$yVAL,$VOLTAGE,$CURRENT,$br_level"
    else
        log_error "Failed to get valid color measurement after $MAX_RETRIES attempts"
        echo "$DATE,$TEMP,$color_prefix,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,$VOLTAGE,$CURRENT,$br_level"
    fi
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        --patternpath=*)
            PATTERNPATH="${arg#*=}"
            NOARGS="no"
            ;;
        --loop=*)
            LOOPCOUNT="${arg#*=}"
            NOARGS="no"
            ;;
        --noheader=*)
            NOHEADER="${arg#*=}"
            NOARGS="no"
            ;;
        --interval=*)
            INTERVAL="${arg#*=}"
            NOARGS="no"
            ;;
        --temp=*)
            TEMPERED="${arg#*=}"
            NOARGS="no"
            ;;
        --power=*)
            POWER="${arg#*=}"
            NOARGS="no"
            ;;
        --wfile=*)
            WFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --rfile=*)
            RFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --gfile=*)
            GFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --bfile=*)
            BFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --cfile=*)
            CFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --mfile=*)
            MFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --yfile=*)
            YFILE="${arg#*=}"
            NOARGS="no"
            ;;
        --brlevel=*)
            BRLEVEL="${arg#*=}"
            NOARGS="no"
            ;;
        --startupimg=*)
            STARTUPIMG="${arg#*=}"
            NOARGS="no"
            ;;
        --measureonly=*)
            MEASUREONLY="${arg#*=}"
            NOARGS="no"
            ;;
        --mypath=*)
            MYPATH="${arg#*=}"
            NOARGS="no"
            ;;
        --help|-h)
            echo "$USAGE"
            exit 0
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "$USAGE"
            exit 1
            ;;
    esac
done

if [ "$NOARGS" = "yes" ]; then
    echo "$USAGE"
    exit 0
fi

# Setup paths
TEMPEREDPATH="$MYPATH/Output/usb-tempered/utils/$TEMPERED"
POWERPATH="$MYPATH/binaries/$POWER"
MPLAYCLT="$MYPATH/brbox/output/bin/mplayclt"

# Use configurable pattern path
WFILEPATH="$PATTERNPATH/$WFILE"
RFILEPATH="$PATTERNPATH/$RFILE"
GFILEPATH="$PATTERNPATH/$GFILE"
BFILEPATH="$PATTERNPATH/$BFILE"
CFILEPATH="$PATTERNPATH/$CFILE"
MFILEPATH="$PATTERNPATH/$MFILE"
YFILEPATH="$PATTERNPATH/$YFILE"

# Validate files
[ ! -f "$TEMPEREDPATH" ] && TEMPEREDPATH="none"
[ ! -f "$POWERPATH" ] && POWERPATH="none"
[ ! -f "$MPLAYCLT" ] && MPLAYCLT="none"
[ ! -f "$WFILEPATH" ] && WFILEPATH="none"
[ ! -f "$RFILEPATH" ] && RFILEPATH="none"
[ ! -f "$GFILEPATH" ] && GFILEPATH="none"
[ ! -f "$BFILEPATH" ] && BFILEPATH="none"
[ ! -f "$CFILEPATH" ] && CFILEPATH="none"
[ ! -f "$MFILEPATH" ] && MFILEPATH="none"
[ ! -f "$YFILEPATH" ] && YFILEPATH="none"

# Check for spotread
if ! check_command spotread; then
    log_error "spotread not found. Please install argyll package."
    exit 1
fi

# Initialize display if needed
if [ "$MEASUREONLY" = "no" ] && [ "$STARTUPIMG" != "none" ]; then
    $MPLAYCLT --showimg=none --showimg="$WFILEPATH" > /dev/null
    sleep 2
fi

# Print CSV header
if [ "$NOHEADER" = "no" ]; then
	echo "DATE,TIME,temp,Sampled-Color,X,Y,Z,Y,x,y,voltage,current,brightnesslevel"
fi

# Main measurement loop
x=1
while [ $x -le "$LOOPCOUNT" ]; do
    if [ "$WFILE" != "none" ]; then
        measure_color "$WFILEPATH" "W" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$RFILE" != "none" ]; then
        measure_color "$RFILEPATH" "R" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$GFILE" != "none" ]; then
        measure_color "$GFILEPATH" "G" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$BFILE" != "none" ]; then
        measure_color "$BFILEPATH" "B" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$CFILE" != "none" ]; then
        measure_color "$CFILEPATH" "C" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$MFILE" != "none" ]; then
        measure_color "$MFILEPATH" "M" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    if [ "$YFILE" != "none" ]; then
        measure_color "$YFILEPATH" "Y" "$TEMPEREDPATH" "none" "$MPLAYCLT" "$POWERPATH" "$BRLEVEL"
        sleep 5
    fi
    
    # Wait between measurements if requested
    if [ "$INTERVAL" != "none" ]; then
        sleep "$INTERVAL"
    fi
    x=$((x + 1))
done

# Cleanup display
if [ "$MEASUREONLY" = "no" ]; then
    $MPLAYCLT --showimg=none > /dev/null
fi
