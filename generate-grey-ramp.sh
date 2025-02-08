#!/bin/sh

# Default values
RESOLUTION="1920x1080"
OUTPUT_FOLDER=""  # Empty by default to enforce mandatory check
VERBOSE=0
COLOR="W"  # Default color (White ramp)

# Function to show help
show_help() {
   echo "Usage: $0 --outputfolder=/path [--resolution=WIDTHxHEIGHT] [--color=R|G|B|W|all] [--verbose]"
   echo "Generates color ramp PNG images (0-255)"
   echo ""
   echo "Options:"
   echo "  --outputfolder=/path    (MANDATORY) Output directory for generated images"
   echo "  --resolution=WIDTHxHEIGHT    Image resolution (default: 1920x1080)"
   echo "  --color=R|G|B|W|all    Color channel for ramp (default: W)"
   echo "                         R = Red ramp (R:0-255, G:0, B:0)"
   echo "                         G = Green ramp (R:0, G:0-255, B:0)"
   echo "                         B = Blue ramp (R:0, G:0, B:0-255)"
   echo "                         W = White ramp (8-bit grayscale 0-255)"
   echo "                         all = Generate all ramps (RGBW)"
   echo "  --verbose               Show detailed progress information"
   echo ""
   echo "Example:"
   echo "  $0 --outputfolder=/tmp/reds --resolution=1280x720 --color=R --verbose"
   echo "  $0 --outputfolder=/tmp/allramps --color=all --verbose"
}

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

# Function to validate color parameter
validate_color() {
   local color=$1
   case "$color" in
       R|G|B|W|all) return 0 ;;
       *)
           error "Invalid color parameter. Must be R, G, B, W, or all"
           error "R = Red ramp (R:0-255, G:0, B:0)"
           error "G = Green ramp (R:0, G:0-255, B:0)"
           error "B = Blue ramp (R:0, G:0, B:0-255)"
           error "W = White ramp (8-bit grayscale 0-255)"
           error "all = Generate all ramps (RGBW)"
           exit 1
           ;;
   esac
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

# Function to get RGB values based on intensity and color choice
get_rgb_values() {
   local intensity=$1
   local color=$2

   case "$color" in
       R) echo "$intensity,0,0" ;;
       G) echo "0,$intensity,0" ;;
       B) echo "0,0,$intensity" ;;
       W) echo "gray($intensity)" ;;
   esac
}

# Function to get color name for output files
get_color_name() {
   local color=$1
   case "$color" in
       R) echo "red" ;;
       G) echo "green" ;;
       B) echo "blue" ;;
       W) echo "gray" ;;
   esac
}

# Function to check available disk space (in MB)
check_disk_space() {
   local folder=$1
   df -m "$folder" 2>/dev/null | awk 'NR==2 {print $4}'
}

# Function to generate ramp for a specific color
generate_ramp() {
    local color=$1
    local color_name=$(get_color_name "$color")

    log "Generating $color_name ramp..."

    i=0
    while [ $i -le 255 ]; do
        rgb_values=$(get_rgb_values "$i" "$color")
        output_file="${OUTPUT_FOLDER}/${color_name}_${i}.png"

        if [ "$color" = "W" ]; then
            # For grayscale, use Gray colorspace with 8-bit depth
            if ! convert -size "${WIDTH}x${HEIGHT}" \
                 -depth 8 \
                 "xc:gray($i)" \
                 -colorspace gray \
                 -define png:bit-depth=8 \
                 -define png:color-type=0 \
                 "$output_file" 2>/dev/null; then
                error "Failed to generate image: $output_file"
                error "Please check if you have sufficient disk space and permissions"
                exit 1
            fi
        else
            # For RGB colors, enforce 8-bit per channel
            if ! convert -size "${WIDTH}x${HEIGHT}" \
                 -depth 8 \
                 "xc:rgb($rgb_values)" \
                 -colorspace RGB \
                 -define png:bit-depth=8 \
                 -define png:color-type=2 \
                 "$output_file" 2>/dev/null; then
                error "Failed to generate image: $output_file"
                error "Please check if you have sufficient disk space and permissions"
                exit 1
            fi
        fi

        # Verify file was created
        if [ ! -f "$output_file" ]; then
            error "Failed to create file: $output_file"
            exit 1
        fi

        # Use 'file' command to verify PNG format
        if ! file "$output_file" | grep -q "PNG image data"; then
            error "Generated file is not a valid PNG: $output_file"
            exit 1
        fi

        progress "Generating $color_name: $((i + 1))/256 images [$(($i * 100 / 255))%]\r"
        i=$((i + 1))
    done

    [ $VERBOSE -eq 1 ] && echo ""
}
# Show help if no arguments provided
if [ $# -eq 0 ]; then
   show_help
   exit 1
fi

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
       --color=*)
           COLOR="${1#*=}"
           validate_color "$COLOR"
           ;;
       --verbose)
           VERBOSE=1
           ;;
       --help)
           show_help
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

# Check if output folder is provided
if [ -z "$OUTPUT_FOLDER" ]; then
   error "Missing mandatory argument: --outputfolder"
   show_help
   exit 1
fi

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

# Calculate required space
required_space=$((WIDTH * HEIGHT * 256 * 4 / 1024 / 1024))
if [ "$COLOR" = "all" ]; then
   required_space=$((required_space * 4))
fi

# Check disk space
available_space=$(check_disk_space "$OUTPUT_FOLDER")

# Only check disk space if we got a valid number
if [ -n "$available_space" ] && [ "$available_space" -lt "$required_space" ]; then
   error "Low disk space!"
   error "Estimated space required: ${required_space}MB"
   if [ "$COLOR" = "all" ]; then
       error "(for all color ramps RGBW)"
   fi
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
if [ "$COLOR" = "all" ]; then
   log "- Color ramp: All (RGBW)"
   log "- Estimated space required: ${required_space}MB"
   log "This will create 1024 ramp PNG files (256 for each RGBW)..."
else
   color_name=$(get_color_name "$COLOR")
   log "- Color ramp: $COLOR ($color_name)"
   log "- Estimated space required: ${required_space}MB"
   log "This will create 256 ${color_name} ramp PNG files..."
fi
log ""

# Generate ramps
if [ "$COLOR" = "all" ]; then
   for c in R G B W; do
       generate_ramp "$c"
   done
else
   generate_ramp "$COLOR"
fi

# Final output only in verbose mode
if [ $VERBOSE -eq 1 ]; then
   total_size=$(du -sh "$OUTPUT_FOLDER" | cut -f1)
   if [ "$COLOR" = "all" ]; then
       printf "\nDone! Generated all color ramps (RGBW) in %s\n" "$OUTPUT_FOLDER"
   else
       color_name=$(get_color_name "$COLOR")
       printf "\nDone! Generated 256 %s ramp images in %s\n" "$color_name" "$OUTPUT_FOLDER"
   fi
   printf "Total size: %s\n" "$total_size"
fi
