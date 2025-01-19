#!/bin/bash

# Directory to save the generated PNG files
OUTPUT_DIR="./patterns"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Resolution and square dimensions
RESOLUTION="2560x1440"
SQUARE_W=400
SQUARE_H=400

# List of colors
COLORS="red green blue cyan magenta yellow white"

# Intensity steps
INTENSITIES="25 50 75 100 125 150 175 200 225 255"

# Loop through each color
for COLOR in $COLORS; do
  # Loop through each intensity
  for INTENSITY in $INTENSITIES; do
    # Generate the output filename
    OUTPUT_FILE="${OUTPUT_DIR}/${COLOR}-${INTENSITY}.png"

    # Run the generate-pattern.sh script
    ./square-box-pattern.sh \
      --resolution="$RESOLUTION" \
      --squareW="$SQUARE_W" \
      --squareH="$SQUARE_H" \
      --intensity="$INTENSITY" \
      --color="$COLOR" \
      --output="$OUTPUT_FILE"

    # Check if the command succeeded
    if [ $? -eq 0 ]; then
      echo "Generated: $OUTPUT_FILE"
    else
      echo "Error generating: $OUTPUT_FILE"
      exit 1
    fi
  done
done

echo "All 70 PNG files have been generated in the '$OUTPUT_DIR' directory."
