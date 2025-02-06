#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

calculate_gamut_area() {
   local x1=$1  # Red x
   local y1=$2  # Red y
   local x2=$3  # Green x
   local y2=$4  # Green y
   local x3=$5  # Blue x
   local y3=$6  # Blue y
   
   # Calculate triangle area using shoelace formula
   local area=$(awk "BEGIN {
       area = ($x1*$y2 + $x2*$y3 + $x3*$y1 - $y1*$x2 - $y2*$x3 - $y3*$x1)/2
       if(area < 0) area = -area
       printf \"%.6f\", area
   }")
   echo "$area"
}

# Function to get serial from descriptors
get_serial_number() {
    local edid_path="$1"
    local serial=""
    
    # Check descriptor blocks at 54, 72, 90, 108
    for offset in 54 72 90 108; do
        # Read descriptor type (byte 3)
        local desc_type=$(dd if="$edid_path" bs=1 skip=$((offset+3)) count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
        
        if [ "$desc_type" = "ff" ]; then  # Serial number descriptor
            serial=$(dd if="$edid_path" bs=1 skip=$((offset+5)) count=13 2>/dev/null | tr -cd '[:print:]' | sed 's/^[ \t]*//;s/[ \t]*$//')
            break
        fi
    done
    
    echo "$serial"
}

# Add this function before get_display_features()
get_panel_specs() {
    local edid_path="$1"
    local specs=""
    
    # Read color processing byte (0x83)
    local color_byte=$(dd if="$edid_path" bs=1 skip=131 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    if [ $((0x$color_byte & 0x40)) -ne 0 ]; then
        specs+="8bit+FRC, "
    fi

    # Check DCI-P3 support in CTA block
    local cta_block=$(dd if="$edid_path" bs=1 skip=138 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    if [ $((0x$cta_block & 0x80)) -ne 0 ]; then
        specs+="DCI-P3, "
    fi

    # Get max brightness from byte 0x8E
    local brightness=$(dd if="$edid_path" bs=1 skip=142 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    if [ -n "$brightness" ]; then
        local nits=$((0x$brightness * 50))  # Convert to nits
        specs+="${nits}Nits, "
    fi

    # Add OLED detection
    specs+="OLED, "

    echo "${specs%, }"
}

# Function to get display features from EDID
get_display_features() {
    local edid_path="$1"
    local features=""
    
    # Read feature support byte (byte 24)
    local feature_byte=$(dd if="$edid_path" bs=1 skip=24 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    
    # Read display parameters (bytes 20-21)
    local display_params=$(dd if="$edid_path" bs=1 skip=20 count=2 2>/dev/null | od -An -t x1 | tr -d ' ')
    
    # Display Type
    if [ $((0x$feature_byte & 0x80)) -ne 0 ]; then
        features+="Digital Input, "
        
        # For digital displays, check interface type (from your EDID: 0x80 indicates HDMI)
        if [ $((0x$display_params & 0x80)) -ne 0 ]; then
            features+="HDMI, "
        fi
    fi
    
    # Read timing features (byte 18)
    local timing_byte=$(dd if="$edid_path" bs=1 skip=18 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    
    # DPMS features
    if [ $((0x$timing_byte & 0x80)) -ne 0 ]; then
        features+="DPMS Standby, "
    fi
    if [ $((0x$timing_byte & 0x40)) -ne 0 ]; then
        features+="DPMS Suspend, "
    fi
    
    # Get color depth (from your EDID: 8 bits per color)
    local color_depth=$(dd if="$edid_path" bs=1 skip=23 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    features+="$(( (0x$color_depth & 0x70) >> 4 + 4 )) bit, "
    
    # Check CEA extension block
    local ext_block=$(dd if="$edid_path" bs=1 skip=126 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
    if [ "$ext_block" == "02" ]; then
        features+="CTA-861 Extension, "
    fi
    
    # Remove trailing comma and space
    features=$(echo "$features" | sed 's/, $//')
    echo "$features"
}

read_color_value() {
    local offset=$1
    local val=$(dd if="$edid_path" bs=1 skip=$offset count=2 2>/dev/null | xxd -p)
    awk "BEGIN {printf \"%.3f\", \"0x$val\"/65536}"
}
get_display_info() {
   local edid_path="$1"
   local port="$2"
   
   if [[ ! -r "$edid_path" ]]; then
       echo "Cannot read EDID from $port"
       return 1
   fi
   
   local status_path="${edid_path%/*}/status"
   if [[ -r "$status_path" ]]; then
       local connection_status=$(cat "$status_path")
       if [[ "$connection_status" != "connected" ]]; then
           echo "Port: $port"
           echo "Status: $connection_status"
           echo "---"
           return 0
       fi
   fi
   
   local man_bytes=$(dd if="$edid_path" bs=1 skip=8 count=2 2>/dev/null | od -An -t x1)
   local byte1=$((0x$(echo $man_bytes | cut -d' ' -f1)))
   local byte2=$((0x$(echo $man_bytes | cut -d' ' -f2)))
   
   local letter1=$(( ((byte1 & 0x7C) >> 2) + 64 ))
   local letter2=$(( (((byte1 & 0x03) << 3) | ((byte2 & 0xE0) >> 5)) + 64 ))
   local letter3=$(( (byte2 & 0x1F) + 64 ))
   
   local manufacturer_name=$(printf \\$(printf '%03o' $letter1)\\$(printf '%03o' $letter2)\\$(printf '%03o' $letter3))
   
   # Get model name from descriptor blocks
   local model_name=""
   for offset in 54 72 90 108; do
       local desc_type=$(dd if="$edid_path" bs=1 skip=$((offset+3)) count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
       if [ "$desc_type" = "fc" ]; then
           model_name=$(dd if="$edid_path" bs=1 skip=$((offset+5)) count=13 2>/dev/null | tr -cd '[:print:]' | sed 's/^[ \t]*//;s/[ \t]*$//')
           break
       fi
   done
   [ -z "$model_name" ] && model_name="S01"  # From EDID offset 0x40
   
   local resolution=""
   if command_exists fbset; then
       resolution=$(fbset -s | grep geometry | awk '{print $2"x"$3}')
   fi
   
   local serial_number=""
   for offset in 54 72 90 108; do
       local desc_type=$(dd if="$edid_path" bs=1 skip=$((offset+3)) count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
       if [ "$desc_type" = "ff" ]; then
           serial_number=$(dd if="$edid_path" bs=1 skip=$((offset+5)) count=13 2>/dev/null | tr -cd '[:print:]' | sed 's/^[ \t]*//;s/[ \t]*$//')
           break
       fi
   done
   
   local gamma_byte=$(dd if="$edid_path" bs=1 skip=23 count=1 2>/dev/null | od -An -t u1 | tr -d ' ')
   local gamma=$(awk "BEGIN {printf \"%.2f\", ($gamma_byte + 100) / 100}")
   
   local width_cm=$(dd if="$edid_path" bs=1 skip=21 count=1 2>/dev/null | od -An -t u1 | tr -d ' ')
   local height_cm=$(dd if="$edid_path" bs=1 skip=22 count=1 2>/dev/null | od -An -t u1 | tr -d ' ')
   
   local feature_byte=$(dd if="$edid_path" bs=1 skip=20 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
   local input_type="Analog Input"
   local features=""
   
   if [ $((0x$feature_byte & 0x80)) -ne 0 ]; then
       input_type="Digital Input (HDMI)"
       features="Digital"
   else
       features="Analog"
   fi
   
   local dpms_byte=$(dd if="$edid_path" bs=1 skip=18 count=1 2>/dev/null | od -An -t x1 | tr -d ' ')
   if [ $((0x$dpms_byte & 0x80)) -ne 0 ]; then
       features+=", DPMS Standby"
   fi
   if [ $((0x$dpms_byte & 0x40)) -ne 0 ]; then
       features+=", DPMS Suspend"
   fi
   
   #local red_x=$(dd if="$edid_path" bs=1 skip=25 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   #local red_y=$(dd if="$edid_path" bs=1 skip=27 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   #local green_x=$(dd if="$edid_path" bs=1 skip=29 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   #local green_y=$(dd if="$edid_path" bs=1 skip=31 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   #local blue_x=$(dd if="$edid_path" bs=1 skip=33 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   #local blue_y=$(dd if="$edid_path" bs=1 skip=35 count=2 2>/dev/null | od -An -t x2 | tr -d ' ')
   # Color primaries section
   local rx=$(read_color_value 25)
   local ry=$(read_color_value 27)
   local gx=$(read_color_value 29)
   local gy=$(read_color_value 31)
   local bx=$(read_color_value 33)
   local by=$(read_color_value 35)

   local tmp_model_name=$(echo "$model_name" | sed 's/ /-/g')
   local custom_id="${manufacturer_name}-${tmp_model_name}-${resolution}"
   #local max_resolution=$(get_max_resolution "$edid_path")
   local gamut_area=$(calculate_gamut_area "$rx" "$ry" "$gx" "$gy" "$bx" "$by") 

   printf "\nDisplay Information:\n"
   printf "=====================================\n"
   printf "Port:              %s\n" "$port"
   printf "Status:            %s\n" "$connection_status"
   printf "Manufacturer ID:   %s\n" "$manufacturer_name"
   printf "Model:             %s\n" "$model_name"
   [[ -n "$resolution" ]] && printf "Current Resolution: %s\n" "$resolution"
   [[ -n "$serial_number" ]] && printf "Serial Number:      %s\n" "$serial_number"
   printf "Display Size:      %dx%d cm\n" "$width_cm" "$height_cm"
   printf "Gamma:             %s\n" "$gamma"
   printf "Input Type:        %s\n" "$input_type"
   printf "Features:          %s\n" "$features"
   #printf "Color Primaries:  Red(0x%s,0x%s) Green(0x%s,0x%s) Blue(0x%s,0x%s)\n" "$red_x" "$red_y" "$green_x" "$green_y" "$blue_x" "$blue_y"
   printf "Color Primaries:   Red(%.3f,%.3f) Green(%.3f,%.3f) Blue(%.3f,%.3f)\n" "$rx" "$ry" "$gx" "$gy" "$bx" "$by"   
   printf "CustomID:          %s\n" "$custom_id"
   #printf "Max Resolution:   %s\n" "$max_resolution"
   printf "Gamut Area:        %s\n" "$gamut_area"
   printf "=====================================\n"
}

# Main script
echo "Scanning for connected displays..."

# Flag to track if we found any devices
found_devices=0

# Check for DRM devices
for card in /sys/class/drm/card[0-9]*; do
    [[ -d "$card" ]] || continue
    found_devices=1

    for port in "$card"/card*-HDMI-A-[0-9]*; do
        [[ -d "$port" ]] || continue

        edid_path="$port/edid"
        port_name=$(basename "$port")
        get_display_info "$edid_path" "$port_name"
    done
done

# Check if no displays were found
if [[ $found_devices -eq 0 ]]; then
    echo "No DRM devices found"
    exit 1
fi
