#!/bin/sh

# Default values
RESOLUTION="1920x1080"
OUTPUT_FOLDER="."
VERBOSE=0

# Function to print verbose messages
log() {
    if [ $VERBOSE -eq 1 ]; then
        echo "$@"
    fi
}

# Function to print progress
progress() {
    if [ $VERBOSE -eq 1 ]; then
        printf "%s" "$1"
    fi
}

# Function to print errors (always shown regardless of verbose mode)
error() {
    echo "Error: $@" >&2
}

# Function to validate resolution format
validate_resolution() {
    local res=$1
    if ! echo "$res" | grep -qE '^[0-9]+x[0-9]+$'; then
        error "Invalid resolution format. Must be WIDTHxHEIGHT (e.g., 1920x1080)"
        exit 1
    fi
}

# Function to validate and create output folder
validate_output_folder() {
    local folder=$1
    
    # Convert to absolute path if relative
    case "$folder" in
        /*) ;;  # Path is absolute, do nothing
        *) folder="$(pwd)/$folder"
           log "Note: Converting to absolute path: $folder"
           ;;
    esac
    # Create parent directories if they don't exist
    parent_dir=$(dirname "$folder")
    if ! mkdir -p "$parent_dir" 2>/dev/null; then
        error "Unable to create parent directory: $parent_dir"
        error "Please check permissions and path validity"
        exit 1
    fi
    
    # Create the output folder itself
    if ! mkdir -p "$folder" 2>/dev/null; then
        error "Unable to create output folder: $folder"
        error "Please check permissions and path validity"
        exit 1
    fi
    
    # Check if folder is writable
    if [ ! -w "$folder" ]; then
        error "Output folder is not writable: $folder"
        exit 1
    fi
    
    echo "$folder"
}

# Function to check available disk space (in MB)
check_disk_space() {
    local folder=$1
    df -m "$folder" 2>/dev/null | awk 'NR==2 {print $4}'
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --outputfolder=*)
            OUTPUT_FOLDER="${1#*=}"
            ;;
        --resolution=*)
            RESOLUTION="${1#*=}"
            validate_resolution "$RESOLUTION"
            ;;
        --verbose)
            VERBOSE=1
            ;;
        --help)
            echo "Usage: $0 [--outputfolder=/path] [--resolution=WIDTHxHEIGHT] [--verbose]"
            echo "Generates 256 greyscale PNG images (0-255)"
            echo ""
            echo "Options:"
            echo "  --outputfolder=/path    Output directory for generated images"
            echo "  --resolution=WIDTHxHEIGHT    Image resolution (default: 1920x1080)"
            echo "  --verbose               Show detailed progress information"
            echo ""
            echo "Example:"
            echo "  $0 --outputfolder=/tmp/greys --resolution=1280x720 --verbose"
            exit 0
            ;;
        *)
            error "Unknown parameter: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Check if ImageMagick is installed
if ! command -v convert >/dev/null 2>&1; then
    error "ImageMagick's convert command not found"
    error "Please install ImageMagick package"
    exit 1
fi

# Validate and create output folder, get absolute path
OUTPUT_FOLDER=$(validate_output_folder "$OUTPUT_FOLDER")

# Extract width and height from resolution
WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

# Check disk space
required_space=$((WIDTH * HEIGHT * 256 * 4 / 1024 / 1024))
available_space=$(check_disk_space "$OUTPUT_FOLDER")

# Only check disk space if we got a valid number
if [ -n "$available_space" ] && [ "$available_space" -lt "$required_space" ]; then
    error "Low disk space!"
    error "Estimated space required: ${required_space}MB"
    error "Available space: ${available_space}MB"
    if [ $VERBOSE -eq 1 ]; then
        printf "Do you want to continue? (y/N) "
        read REPLY
        case "$REPLY" in
            [Yy]*) ;;
            *) exit 1 ;;
        esac
    else
        exit 1
    fi
fi

# Show configuration if verbose
log "Configuration:"
log "- Resolution: ${WIDTH}x${HEIGHT}"
log "- Output folder: $OUTPUT_FOLDER"
log "- Estimated space required: ${required_space}MB"
log "This will create 256 PNG files..."
log ""

# Generate greyscale images
i=0
while [ $i -le 255 ]; do
    output_file="${OUTPUT_FOLDER}/grey_${i}.png"
    if ! convert -size "${WIDTH}x${HEIGHT}" "xc:rgb($i,$i,$i)" "$output_file" 2>/dev/null; then
        error "Failed to generate image: $output_file"
        error "Please check if you have sufficient disk space and permissions"
        exit 1
    fi
    
    # Show progress only in verbose mode
    progress "Generating: $((i + 1))/256 images [$(($i * 100 / 255))%]\r"
    i=$((i + 1))
done

# Final output only in verbose mode
if [ $VERBOSE -eq 1 ]; then
    total_size=$(du -sh "$OUTPUT_FOLDER" | cut -f1)
    printf "\nDone! Generated 256 greyscale images in %s\n" "$OUTPUT_FOLDER"
    printf "Total size: %s\n" "$total_size"
fi
