#!/bin/sh

usage() {
   echo "Usage: $0 --input=INPUT_FILE --output=OUTPUT_FILE"
   exit 1
}

# Parse arguments
for arg in "$@"; do
   case $arg in
       --input=*)
           input="${arg#*=}"
           ;;
       --output=*)
           output="${arg#*=}"
           ;;
       *)
           usage
           ;;
   esac
done

[ -z "$input" ] || [ -z "$output" ] && usage
[ ! -f "$input" ] && echo "Input file not found" && exit 1

# Write header
echo "Color,Level,Y,x,y" > "$output"

# Extract and format required columns
sed -n '2,$p' "$input" | while IFS=, read -r _ _ _ Col _ Y _ _ x y _ _ level; do
   printf "%s,%s,%s,%s,%s\n" "$Col" "$level" "$Y" "$x" "$y" >> "$output"
done
