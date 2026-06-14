#!/usr/bin/env python3
"""
Simple file concatenation for Viterbi Decoder
Just concatenates N.dat, A.dat, B.dat, and input.dat
"""

import sys

def read_file_lines(filename):
    """Read all non-empty lines from a file"""
    lines = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                lines.append(line)
    return lines

def combine_files_simple(n_file, a_file, b_file, input_file, output_file):
    """
    Simply concatenate all input files in order
    """
    print(f"Reading files...")
    
    # Read all files
    n_lines = read_file_lines(n_file)
    a_lines = read_file_lines(a_file)
    b_lines = read_file_lines(b_file)
    input_lines = read_file_lines(input_file)
    
    print(f"  N file:     {len(n_lines)} lines")
    print(f"  A file:     {len(a_lines)} lines")
    print(f"  B file:     {len(b_lines)} lines")
    print(f"  Input file: {len(input_lines)} lines")
    
    # Write combined file
    with open(output_file, 'w') as f:
        # Write N.dat
        for line in n_lines:
            f.write(line + '\n')
        
        # Write A.dat
        for line in a_lines:
            f.write(line + '\n')
        
        # Write B.dat
        for line in b_lines:
            f.write(line + '\n')
        
        # Write input.dat
        for line in input_lines:
            f.write(line + '\n')
    
    total_lines = len(n_lines) + len(a_lines) + len(b_lines) + len(input_lines)
    print(f"\n[DONE] Combined file written to {output_file}")
    print(f"Total lines: {total_lines}")

def main():
    if len(sys.argv) != 6:
        print("Usage: python combine_files.py N_file A_file B_file input_file combined.dat")
        sys.exit(1)
    
    n_file = sys.argv[1]
    a_file = sys.argv[2]
    b_file = sys.argv[3]
    input_file = sys.argv[4]
    combined_file = sys.argv[5]
    
    combine_files_simple(n_file, a_file, b_file, input_file, combined_file)

if __name__ == "__main__":
    main()

