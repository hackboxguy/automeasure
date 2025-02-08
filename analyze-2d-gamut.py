#!/usr/bin/env python3
#./analyze-2d-gamut.py --inputcsv=test-data.csv --reference=ntsc --output=analysis.jpg
import argparse
import sys
import pandas as pd
import numpy as np
from matplotlib import pyplot as plt
import matplotlib
from matplotlib.patches import Polygon
from shapely.geometry import Polygon as ShapelyPolygon
import colour
from colour.plotting import plot_chromaticity_diagram_CIE1931
from matplotlib.patches import Ellipse
import numpy as np

REFERENCE_GAMUTS = {
    'ntsc': {
        'primaries': np.array([[0.67, 0.33], [0.21, 0.71], [0.14, 0.08]]),
        'white': np.array([0.3101, 0.3162]),  # CIE Illuminant C
        'label': 'NTSC 1953'
    },
    'srgb': {
        'primaries': np.array([[0.64, 0.33], [0.30, 0.60], [0.15, 0.06]]),
        'white': np.array([0.3127, 0.3290]),  # D65
        'label': 'sRGB'
    },
    #'dcip3': {
    #    'primaries': np.array([[0.68, 0.32], [0.265, 0.69], [0.15, 0.06]]),
    #    'white': np.array([0.314, 0.351]),    # DCI White
    #    'label': 'DCI-P3'
    #},
    'dcip3': {
        'primaries': np.array([[0.68, 0.32], [0.265, 0.69], [0.15, 0.06]]),
        'white': np.array([0.3127, 0.3290]),  # D65 is the standard white point for DCI-P3-D65
        'label': 'DCI-P3'
    },
    'rec709': {
        'primaries': np.array([[0.64, 0.33], [0.30, 0.60], [0.15, 0.06]]),
        'white': np.array([0.3127, 0.3290]),  # D65
        'label': 'Rec.709'
    },
    'rec2020': {
        'primaries': np.array([[0.708, 0.292], [0.170, 0.797], [0.131, 0.046]]),
        'white': np.array([0.3127, 0.3290]),  # D65
        'label': 'Rec.2020'
    }
}

def analyze_white_point(ax, w_measured, w_reference, tolerance):
    """
    Analyze and visualize white point tolerance
    Returns True if measured point is within tolerance ellipse
    """
    # Convert tolerance to major/minor axes of ellipse
    # Using approximation based on MacAdam ellipses - y-axis sensitivity is roughly 3x x-axis
    major_axis = tolerance *1.2
    minor_axis = tolerance #/ 3  # x-axis tolerance is smaller due to higher sensitivity
    # Minimal rotation to keep it more standard
    rotation_angle = -10
    # Create and add tolerance ellipse
    ellipse = Ellipse(xy=w_reference, width=major_axis*2, height=minor_axis*2,
                      angle=rotation_angle, fill=False, color='gray', linestyle=':',
                      label=f'Tolerance (±{tolerance:.3f})')
    ax.add_patch(ellipse)
    # Calculate if measured point is within ellipse
    dx = w_measured[0] - w_reference[0]
    dy = w_measured[1] - w_reference[1]
    # Check if point is within ellipse using normalized coordinates
    is_within = (dx/minor_axis)**2 + (dy/major_axis)**2 <= 1
    # Calculate distance in terms of tolerance units
    distance = np.sqrt((dx/minor_axis)**2 + (dy/major_axis)**2)
    return is_within, distance

def validate_xy_coordinates(x, y):
    """Validate if xy coordinates are within valid chromaticity range"""
    try:
        x = float(x)
        y = float(y)
        if not (0 <= x <= 1 and 0 <= y <= 1 and x + y <= 1):
            raise ValueError(f"Invalid chromaticity coordinates: x={x}, y={y}")
        return True
    except (ValueError, TypeError):
        raise ValueError(f"Invalid coordinate values: x={x}, y={y}")

def calculate_area(points):
    """Calculate polygon area using shoelace formula"""
    # Convert points to list of tuples for easy comparison
    points = [(float(p[0]), float(p[1])) for p in points]
    
    # Close the polygon if not already closed
    if points[0] != points[-1]:
        points.append(points[0])
    
    x = [p[0] for p in points]
    y = [p[1] for p in points]
    
    return 0.5 * abs(sum(i * j for i, j in zip(x, y[1:] + y[:1])) - 
                    sum(i * j for i, j in zip(x[1:] + x[:1], y)))

def process_measurements(df):
    """Process and validate measurement data"""
    required_colors = {'R', 'G', 'B', 'W'}
    measured_colors = set(df['Color'])
    
    if not required_colors.issubset(measured_colors):
        missing = required_colors - measured_colors
        raise ValueError(f"Missing measurements for: {missing}")
    
    measured = {}
    for _, row in df.iterrows():
        try:
            x, y = float(row.x), float(row.y)
            validate_xy_coordinates(x, y)
            measured[row.Color] = (x, y)  # Store as tuple
        except ValueError as e:
            raise ValueError(f"Invalid measurement for {row.Color}: {e}")
    
    return measured

def main():
    parser = argparse.ArgumentParser(description='Color Gamut Analyzer')
    parser.add_argument('--inputcsv', required=True, help='Measurement CSV file')
    parser.add_argument('--inputcsvcold', help='Cold measurement CSV file (optional, initial startup)')
    parser.add_argument('--reference', required=True, 
                       choices=REFERENCE_GAMUTS.keys(), help='Reference standard')
    parser.add_argument('--output', help='Output plot filename (jpg/png/pdf)')
    parser.add_argument('--title', help='Custom title for the plot')
    parser.add_argument('--whitepointtol', type=float,
                   help='White point tolerance (if not specified, tolerance visualization is skipped)')
    args = parser.parse_args()

    try:
        # Set backend based on mode
        if args.output:
            matplotlib.use('Agg')
        else:
            matplotlib.use('TkAgg')
        
        # Load and validate data
        df = pd.read_csv(args.inputcsv)
        required_columns = {'Color', 'x', 'y','Y'}
        if not required_columns.issubset(df.columns):
            raise ValueError(f"CSV must contain columns: {required_columns}")
        
        # Process measurements
        measured = process_measurements(df)
        ref = REFERENCE_GAMUTS[args.reference]
        
        # Process cold measurements if provided
        cold_measured = None
        if args.inputcsvcold:
            df_cold = pd.read_csv(args.inputcsvcold)
            if not required_columns.issubset(df_cold.columns):
                raise ValueError(f"Cold measurement CSV must contain columns: {required_columns}")
            cold_measured = process_measurements(df_cold)

        # Create figure
        plt.close('all')
        fig = plt.figure(figsize=(10, 10))
        
        # Plot CIE diagram
        plot_chromaticity_diagram_CIE1931(
            axes=plt.gca(),
            show=False,
            title=False
        )
        ax = plt.gca()
        
        # Prepare polygon points
        m_points = [(float(measured[c][0]), float(measured[c][1])) for c in ['R', 'G', 'B']]
        r_points = [(float(p[0]), float(p[1])) for p in ref['primaries']]

        # Calculate areas
        m_area = calculate_area(m_points)
        r_area = calculate_area(r_points)
        
        # Calculate coverage
        poly1 = ShapelyPolygon(m_points)
        poly2 = ShapelyPolygon(r_points)
        overlap = poly1.intersection(poly2)
        coverage = overlap.area / r_area * 100 if not overlap.is_empty else 0
        relative_area = (m_area / r_area) * 100

        # Calculate white point differences
        w_measured = measured['W']
        w_reference = ref['white']
        delta_x = w_measured[0] - w_reference[0]
        delta_y = w_measured[1] - w_reference[1]

        # Plot warm measured gamut
        ax.add_patch(Polygon(
            m_points, closed=True, fill=False,
            edgecolor='black', linewidth=2, linestyle='--',
            label=f'Measured ({m_area:.3f})'
        ))

        # Plot cold measured gamut(if available)
        if cold_measured:
            c_points = [(float(cold_measured[c][0]), float(cold_measured[c][1]))
                       for c in ['R', 'G', 'B']]
            c_area = calculate_area(c_points)
            c_poly = ShapelyPolygon(c_points)
            c_overlap = c_poly.intersection(poly2)
            c_coverage = c_overlap.area / r_area * 100 if not c_overlap.is_empty else 0
            c_relative_area = (c_area / r_area) * 100
            # Plot cold gamut
            ax.add_patch(Polygon(
                c_points, closed=True, fill=False,
                edgecolor='blue', linewidth=2, linestyle='--',
                label=f'Measured Cold ({c_area:.3f})'
            ))
            # Plot cold white point
            #w_cold = cold_measured['W']
            #ax.plot(w_cold[0], w_cold[1], 'bx', markersize=8,
            #       label=f'Cold White ({w_cold[0]:.3f}, {w_cold[1]:.3f})')


        # Plot reference gamut
        ax.add_patch(Polygon(
            r_points, closed=True, fill=False,
            edgecolor='gray', linewidth=2, linestyle='--',
            label=f'{ref["label"]} ({r_area:.3f})'
        ))

        # Plot white points
        ax.plot(w_measured[0], w_measured[1], 'kx', markersize=10,
               label=f'Measured White ({w_measured[0]:.3f}, {w_measured[1]:.3f})')
        ax.plot(w_reference[0], w_reference[1], 'x',color='grey', markersize=10,
               label=f'Reference White ({w_reference[0]:.3f}, {w_reference[1]:.3f})')
        if cold_measured:
            w_cold = cold_measured['W']
            ax.plot(w_cold[0], w_cold[1], 'bx', markersize=8,
                   label=f'Cold White ({w_cold[0]:.3f}, {w_cold[1]:.3f})')

        w_luminance = df.loc[df['Color'] == 'W', 'Y'].values[0]
        # Add info box
        info_text = (f'Luminance: {w_luminance:.1f} cd/m²\n'
                    f'Coverage: {coverage:.1f}%\n'
                    f'Overlap Area: {overlap.area:.3f}\n'
                    f'Relative Area: {relative_area:.1f}%\n'
                    f'White Point Δx: {delta_x:+.4f}\n'
                    f'White Point Δy: {delta_y:+.4f}')

        # Add cold measurements to info text
        if cold_measured:
            w_luminancecold = df_cold.loc[df_cold['Color'] == 'W', 'Y'].values[0]
            info_text += f'\nCold Measurements:'
            info_text += f'\nLuminance: {w_luminancecold:.1f} cd/m²'
            info_text += f'\nCoverage: {c_coverage:.1f}%'
            info_text += f'\nRelative Area: {c_relative_area:.1f}%'
            info_text += f'\nWhite Point Δx: {w_cold[0]-w_reference[0]:+.4f}'
            info_text += f'\nWhite Point Δy: {w_cold[1]-w_reference[1]:+.4f}'

        # Add tolerance analysis only if --whitepointtol is provided
        if args.whitepointtol is not None:
            is_within, distance = analyze_white_point(ax, w_measured, w_reference, args.whitepointtol)
            info_text += f'\nWhite Point Distance: {distance:.3f}x tolerance\n'
            status_text = 'Pass' if is_within else 'Fail'
            status_color = 'g' if is_within else 'r'  # 'g' for green, 'r' for red
            info_text += f'Within Tolerance: {"Yes" if is_within else "No"}'
            print("\nWhite Point Tolerance Analysis:")
            print(f"Tolerance Setting: ±{args.whitepointtol:.3f}")
            print(f"Distance (in tolerance units): {distance:.3f}")
            print(f"Within Tolerance: {'Yes' if is_within else 'No'}")

        if cold_measured:
            # Add to numerical analysis output
            print("\nCold Measurement Analysis:")
            print(f"Luminance: {w_luminancecold:.1f} cd/m²")
            print(f"Coverage: {c_coverage:.1f}%")
            print(f"Relative Area: {c_relative_area:.1f}%")
            print("\nCold White Point Analysis:")
            print(f"Cold White: ({w_cold[0]:.4f}, {w_cold[1]:.4f})")
            print(f"Δx: {w_cold[0]-w_reference[0]:+.4f}")
            print(f"Δy: {w_cold[1]-w_reference[1]:+.4f}")

        plt.text(0.02, 0.98,
                info_text,
                transform=ax.transAxes, fontsize=10,
                bbox=dict(facecolor='white', alpha=0.8),
                verticalalignment='top')

        # Finalize plot
        ax.legend(loc='upper right', bbox_to_anchor=(1.0, 1.0))
        title = args.title if args.title else 'Color Gamut Analysis on CIE 1931 Diagram'
        plt.title(title)
        plt.tight_layout()

        # Save or show plot
        if args.output:
            plt.savefig(args.output, bbox_inches='tight', dpi=300)
        else:
            plt.show()
        plt.close(fig)

        # Print numerical results
        print("\nNumerical Analysis:")
        print(f"Reference Gamut: {ref['label']}")
        print(f"Measured Gamut Area: {m_area:.6f}")
        print(f"Reference Gamut Area: {r_area:.6f}")
        print(f"Overlap Area: {overlap.area:.6f}")
        print(f"Coverage: {coverage:.1f}%")
        print(f"Relative Area: {relative_area:.1f}%")
        print(f"Luminance: {w_luminance:.1f} cd/m²%")
        print("\nWhite Point Analysis:")
        print(f"Measured White: ({w_measured[0]:.4f}, {w_measured[1]:.4f})")
        print(f"Reference White: ({w_reference[0]:.4f}, {w_reference[1]:.4f})")
        print(f"Δx: {delta_x:+.4f}")
        print(f"Δy: {delta_y:+.4f}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        plt.close('all')
        sys.exit(1)

if __name__ == '__main__':
    main()
