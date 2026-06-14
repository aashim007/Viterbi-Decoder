#!/usr/bin/env python3

"""
Random Viterbi Test Generator
Generates random test cases with varying N, M, and varied sequence lengths
Constraint: N * sequence_length < 1024
"""

import numpy as np
import struct
import os
import sys
from pathlib import Path

def float_to_hex(f):
    """Convert float32 to 8-digit hex string"""
    packed = struct.pack('!f', np.float32(f))
    hex_val = struct.unpack('!I', packed)[0]
    return f"{hex_val:08X}"

def generate_random_log_probs(rows, cols, min_log=-10.0, max_log=-0.01):
    """Generate random log probabilities (all negative values)"""
    log_probs = np.random.uniform(min_log, max_log, size=(rows, cols))
    return log_probs.astype(np.float32)

def write_N_file(filepath, N, M):
    """Write N and M as hex values"""
    with open(filepath, 'w') as f:
        f.write(f"{N:X}\n")
        f.write(f"{M:X}\n")

def write_matrix_file(filepath, matrix):
    """Write matrix as hex-encoded float32 values"""
    with open(filepath, 'w') as f:
        for value in matrix.flatten():
            hex_val = float_to_hex(value)
            f.write(f"{hex_val}\n")

def generate_varied_sequences(N, M, num_sequences=10):
    """
    Generate sequences with varied lengths based on N
    Constraint: N * seq_length < 1024

    Distribution:
    - 40% short sequences
    - 50% medium sequences
    - 10% long sequences
    
    All ranges are proportional to max_length (1024/N):
    - Short: 2 to 10% of max_length
    - Medium: 10% to 60% of max_length
    - Long: 60% to 100% of max_length
    """
    max_length = 1024 // N
    sequences = []

    # Calculate how many of each type
    num_short = max(1, int(num_sequences * 0.40))
    num_medium = max(1, int(num_sequences * 0.50))
    num_long = num_sequences - num_short - num_medium

    # Calculate proportional boundaries
    # Short: 2 to 10% of max_length (minimum 2)
    short_min = 2
    short_max = max(10, int(max_length * 0.10))
    
    # Medium: 10% to 60% of max_length
    medium_min = max(short_max + 1, int(max_length * 0.10))
    medium_max = max(medium_min + 1, int(max_length * 0.60))
    
    # Long: 60% to 100% of max_length
    long_min = max(medium_max + 1, int(max_length * 0.60))
    long_max = max_length

    # Generate short sequences
    for _ in range(num_short):
        if short_max > short_min:
            length = np.random.randint(short_min, short_max + 1)
        else:
            length = short_min
        seq = np.random.randint(1, M + 1, size=length).tolist()
        sequences.append(seq)

    # Generate medium sequences
    for _ in range(num_medium):
        if medium_max > medium_min:
            length = np.random.randint(medium_min, medium_max + 1)
        else:
            length = medium_min
        seq = np.random.randint(1, M + 1, size=length).tolist()
        sequences.append(seq)

    # Generate long sequences
    for _ in range(num_long):
        if long_max > long_min:
            length = np.random.randint(long_min, long_max + 1)
        else:
            length = long_max
        seq = np.random.randint(1, M + 1, size=length).tolist()
        sequences.append(seq)

    return sequences

def write_input_file(filepath, sequences):
    """Write input observation sequences"""
    with open(filepath, 'w') as f:
        for seq in sequences:
            for obs in seq:
                f.write(f"{obs:X}\n")
            f.write("FFFFFFFF\n")
        f.write("00000000\n")

def generate_test(test_dir, test_num, N, M, num_sequences=10):
    """Generate a complete test case"""
    test_path = Path(test_dir) / f"test_random_{test_num}"
    test_path.mkdir(parents=True, exist_ok=True)

    max_len = 1024 // N
    print(f"Generating {test_path.name} (N={N:2d}, M={M:2d}, num_seq={num_sequences:2d}, max_len={max_len:4d})")

    write_N_file(test_path / "N.dat", N, M)

    # A matrix: (N+1) x N transition probabilities
    A = generate_random_log_probs(N + 1, N)
    write_matrix_file(test_path / "A.dat", A)

    # B matrix: N x M emission probabilities
    B = generate_random_log_probs(N, M)
    write_matrix_file(test_path / "B.dat", B)

    # Input sequences with varied lengths
    sequences = generate_varied_sequences(N, M, num_sequences)
    write_input_file(test_path / "input.dat", sequences)

    # Print sequence length statistics
    lengths = [len(s) for s in sequences]
    print(f"  → Sequence lengths: min={min(lengths)}, max={max(lengths)}, avg={sum(lengths)/len(lengths):.1f}")

    return test_path.name

def main():
    if len(sys.argv) > 1:
        tests_base_dir = sys.argv[1]
    else:
        tests_base_dir = "tests"

    # Configuration
    num_tests = 10
    # num_tests = 100

    # Distribution ratios
    small_ratio = 0.40   # 40% small tests
    medium_ratio = 0.50  # 50% medium tests
    large_ratio = 0.10   # 10% large tests

    # Calculate number of each type
    num_small = int(num_tests * small_ratio)
    num_medium = int(num_tests * medium_ratio)
    num_large = num_tests - num_small - num_medium

    print("="*70)
    print("Random Viterbi Test Generator with Proportional Sequence Lengths")
    print("="*70)
    print(f"Output directory: {tests_base_dir}")
    print(f"Total tests: {num_tests}")
    print(f"  - Small tests (N=1-7, M=1-7): {num_small}")
    print(f"  - Medium tests (N=8-15, M=8-15): {num_medium}")
    print(f"  - Large tests (N=16-31, M=16-31): {num_large}")
    print()
    print("Sequence length distribution per test (proportional to max_length):")
    print("  - 40% short sequences (2 to 10% of max)")
    print("  - 50% medium sequences (10% to 60% of max)")
    print("  - 10% long sequences (60% to 100% of max)")
    print(f"Constraint: N * sequence_length < 1024")
    print()

    test_configs = []

    # Small tests (N=1-7, M=1-7) - more sequences since N is small
    for i in range(num_small):
        N = np.random.randint(1, 8)
        M = np.random.randint(1, 8)
        num_seq = np.random.randint(8, 16)  # 8-15 sequences
        test_configs.append((N, M, num_seq))

    # Medium tests (N=8-15, M=8-15) - moderate number of sequences
    for i in range(num_medium):
        N = np.random.randint(8, 16)
        M = np.random.randint(8, 16)
        num_seq = np.random.randint(5, 11)  # 5-10 sequences
        test_configs.append((N, M, num_seq))

    # Large tests (N=16-31, M=16-31) - fewer sequences since length is limited
    for i in range(num_large):
        N = np.random.randint(16, 32)
        M = np.random.randint(16, 32)
        num_seq = np.random.randint(3, 8)   # 3-7 sequences
        test_configs.append((N, M, num_seq))

    # Generate tests
    generated = []
    for i, (N, M, num_seq) in enumerate(test_configs, start=1):
        test_name = generate_test(tests_base_dir, i, N, M, num_seq)
        generated.append(test_name)

    print()
    print("="*70)
    print(f"Successfully generated {len(generated)} test cases")
    print("="*70)

    # Create a test list file
    test_list_file = Path(tests_base_dir) / "random_tests.txt"
    with open(test_list_file, 'w') as f:
        f.write("# Random test cases\n")
        for test_name in generated:
            f.write(f"{test_name}\n")
    
if __name__ == "__main__":
    main()

