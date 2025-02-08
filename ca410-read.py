import serial
import time

def read_ca410(port='/dev/ttyUSB0'):
    with serial.Serial(port, 115200, timeout=1) as ser:
        # Initialize
        ser.write(b'RMT 1\r')  # Remote mode
        time.sleep(0.5)
        
        # Trigger measurement
        ser.write(b'MES\r')
        time.sleep(0.5)
        
        # Read values
        ser.write(b'MDA 1\r')
        response = ser.readline().decode('ascii').strip()
        
        # Parse response
        # Format: Y,x,y,T,duv (where Y is luminance in cd/m²)
        values = response.split(',')
        if len(values) >= 3:
            return {
                'x': float(values[1]),    # x chromaticity
                'y': float(values[2]),    # y chromaticity
                'Y': float(values[0]),    # luminance in cd/m²
            }
        return None

# Usage
result = read_ca410()
if result:
    print(f"xyY color space measurements:")
    print(f"x: {result['x']}")
    print(f"y: {result['y']}")
    print(f"Y: {result['Y']} cd/m²")
