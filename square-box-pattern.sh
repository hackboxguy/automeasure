#!/bin/bash

# Default values
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_INTENSITY=255
DEFAULT_SQUARE_W=200
DEFAULT_SQUARE_H=200

# Function to check for ImageMagick dependency
check_dependency() {
  if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick (convert) is not installed."
    echo "To install ImageMagick, run:"
    echo "  sudo apt-get install imagemagick  # For Debian/Ubuntu"
    echo "  sudo yum install imagemagick      # For CentOS/RHEL"
    echo "  brew install imagemagick          # For macOS (Homebrew)"
    exit 1
  fi
}

# Check for ImageMagick dependency
check_dependency

# Function to display usage
usage() {
  echo "Usage: $0 --color=COLOR [--resolution=WxH] [--intensity=INTENSITY] [--output=FILENAME] [--squareW=WIDTH] [--squareH=HEIGHT]"
  echo "  --color:       Mandatory. Supported colors: red, green, blue, cyan, magenta, yellow, white"
  echo "  --resolution:  Optional. Default: $DEFAULT_RESOLUTION"
  echo "  --intensity:   Optional. Default: $DEFAULT_INTENSITY"
  echo "  --output:      Optional. Default: <color>-<intensity>.png"
  echo "  --squareW:     Optional. Width of the square in pixels. Default: $DEFAULT_SQUARE_W"
  echo "  --squareH:     Optional. Height of the square in pixels. Default: $DEFAULT_SQUARE_H"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resolution=*)
      RESOLUTION="${1#*=}"
      ;;
    --color=*)
      COLOR="${1#*=}"
      ;;
    --intensity=*)
      INTENSITY="${1#*=}"
      ;;
    --output=*)
      OUTPUT="${1#*=}"
      ;;
    --squareW=*)
      SQUARE_W="${1#*=}"
      ;;
    --squareH=*)
      SQUARE_H="${1#*=}"
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
  shift
done

# Validate mandatory argument
if [ -z "$COLOR" ]; then
  echo "Error: --color is a mandatory argument."
  usage
fi

# Set default values for optional arguments if not provided
RESOLUTION=${RESOLUTION:-$DEFAULT_RESOLUTION}
INTENSITY=${INTENSITY:-$DEFAULT_INTENSITY}
SQUARE_W=${SQUARE_W:-$DEFAULT_SQUARE_W}
SQUARE_H=${SQUARE_H:-$DEFAULT_SQUARE_H}

# Generate output filename if not provided
if [ -z "$OUTPUT" ]; then
  OUTPUT="${COLOR}-${INTENSITY}.png"
fi

# Extract width and height from resolution
WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

# Validate square dimensions
if [ "$SQUARE_W" -gt "$WIDTH" ] || [ "$SQUARE_H" -gt "$HEIGHT" ]; then
  echo "Error: Square dimensions (${SQUARE_W}x${SQUARE_H}) cannot exceed image resolution (${WIDTH}x${HEIGHT})."
  exit 1
fi

# Calculate the position to center the square
POS_X=$(( (WIDTH - SQUARE_W) / 2 ))
POS_Y=$(( (HEIGHT - SQUARE_H) / 2 ))

# Determine the color based on the input
case "$COLOR" in
  red)
    COLOR_CODE="rgb($INTENSITY,0,0)"
    ;;
  green)
    COLOR_CODE="rgb(0,$INTENSITY,0)"
    ;;
  blue)
    COLOR_CODE="rgb(0,0,$INTENSITY)"
    ;;
  cyan)
    COLOR_CODE="rgb(0,$INTENSITY,$INTENSITY)"
    ;;
  magenta)
    COLOR_CODE="rgb($INTENSITY,0,$INTENSITY)"
    ;;
  yellow)
    COLOR_CODE="rgb($INTENSITY,$INTENSITY,0)"
    ;;
  white)
    COLOR_CODE="rgb($INTENSITY,$INTENSITY,$INTENSITY)"
    ;;
  *)
    echo "Unsupported color: $COLOR"
    echo "Supported colors: red, green, blue, cyan, magenta, yellow, white"
    exit 1
    ;;
esac

# Generate the image
convert -size "${WIDTH}x${HEIGHT}" xc:black -fill "$COLOR_CODE" -draw "rectangle $POS_X,$POS_Y $((POS_X + SQUARE_W)),$((POS_Y + SQUARE_H))" "$OUTPUT"

echo "Image generated successfully: $OUTPUT"
