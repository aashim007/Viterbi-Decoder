#!/usr/bin/env python3

"""
Viterbi Output Checker for Bluespec Testbench
Compares outputs with configurable FP Precision tolerance
"""

import struct
import sys

def hex_to_float(hex_str):
    """Convert hex to float32"""
    val = int(hex_str, 16)
    return struct.unpack('!f', struct.pack('!I', val))[0]

def compare_files(file1, file2, fp_tolerance=2):
    """
    Compare two output files with FP Precision tolerance
    Returns True if all values match within tolerance
    """
    print(f"Comparing: {file1} vs {file2}")
    print(f"FP Precision tolerance: ±{fp_tolerance}")
    print("=" * 70)
    
    with open(file1, 'r') as f1, open(file2, 'r') as f2:
        lines1 = [l.strip() for l in f1 if l.strip()]
        lines2 = [l.strip() for l in f2 if l.strip()]
    
    if len(lines1) != len(lines2):
        print(f"ERROR: Different file lengths: {len(lines1)} vs {len(lines2)}")
        return False
    
    all_pass = True
    seq_num = 0
    line_num = 0
    
    # Track failures for summary
    state_failures = []
    prob_failures = []
    marker_failures = []
    max_fp_diff = 0
    max_float_diff = 0.0
    
    for i, (l1, l2) in enumerate(zip(lines1, lines2)):
        line_num += 1
        v1 = int(l1, 16)
        v2 = int(l2, 16)
        
        # Handle markers (0xFFFFFFFF and 0x00000000)
        if v1 == 0xFFFFFFFF or v1 == 0:
            if v1 != v2:
                marker_failures.append({
                    'seq': seq_num,
                    'line': line_num,
                    'expected': l1,
                    'actual': l2
                })
                all_pass = False
            if v1 == 0xFFFFFFFF:
                seq_num += 1
            continue
        
        # Check if this is a state (small value) or probability (larger value)
        if v1 < 1000 and v2 < 1000:  # Likely states
            if v1 != v2:
                state_failures.append({
                    'seq': seq_num,
                    'line': line_num,
                    'expected': v1,
                    'actual': v2,
                    'expected_hex': l1,
                    'actual_hex': l2
                })
                all_pass = False
        else:  # Probability values
            fp_diff = abs(v1 - v2)
            f1_val = hex_to_float(l1)
            f2_val = hex_to_float(l2)
            float_diff = abs(f1_val - f2_val)
            
            # Update max differences
            max_fp_diff = max(max_fp_diff, fp_diff)
            max_float_diff = max(max_float_diff, float_diff)
            
            if fp_diff > fp_tolerance:
                prob_failures.append({
                    'seq': seq_num,
                    'line': line_num,
                    'expected_hex': l1,
                    'actual_hex': l2,
                    'expected_float': f1_val,
                    'actual_float': f2_val,
                    'fp_diff': fp_diff,
                    'float_diff': float_diff
                })
                all_pass = False
    
    if marker_failures:
        print(f"\nMARKER MISMATCHES: {len(marker_failures)}")
        print("-" * 70)
        for fail in marker_failures:
            print(f"  Seq {fail['seq']}, Line {fail['line']}:")
            print(f"    Expected: {fail['expected']}")
            print(f"    Actual:   {fail['actual']}")
    
    if state_failures:
        print(f"\nSTATE MISMATCHES: {len(state_failures)}")
        print("-" * 70)
        for fail in state_failures:
            print(f"  Seq {fail['seq']}, Line {fail['line']}:")
            print(f"    Expected: {fail['expected']} (0x{fail['expected_hex']})")
            print(f"    Actual:   {fail['actual']} (0x{fail['actual_hex']})")
    
    if prob_failures:
        print(f"\nPROBABILITY MISMATCHES: {len(prob_failures)}")
        print("-" * 70)
        for fail in prob_failures:
            print(f"  Seq {fail['seq']}, Line {fail['line']}:")
            print(f"    Expected: 0x{fail['expected_hex']} = {fail['expected_float']:.10f}")
            print(f"    Actual:   0x{fail['actual_hex']} = {fail['actual_float']:.10f}")
            print(f"    FP diff:  {fail['fp_diff']} (tolerance: {fp_tolerance})")
            print()
    
    # Print summary statistics
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"State mismatches:         {len(state_failures)}")
    print(f"Probability mismatches:   {len(prob_failures)}")
    print(f"Total failures:           {len(marker_failures) + len(state_failures) + len(prob_failures)}")
    print(f"Max precision difference: {max_fp_diff}")
    print("=" * 70)
    
    if all_pass:
        print("PASS: ALL CHECKS PASSED")
        return True
    else:
        print("FAIL: SOME CHECKS FAILED")
        return False

def main():
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: python check_viterbi_output.py output1.dat output2.dat [fp_tolerance]")
        print("  fp_tolerance: Maximum acceptable FP Precision difference (default: 2)")
        sys.exit(1)
    
    file1 = sys.argv[1]
    file2 = sys.argv[2]
    fp_tol = int(sys.argv[3]) if len(sys.argv) == 4 else 2
    
    success = compare_files(file1, file2, fp_tol)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

