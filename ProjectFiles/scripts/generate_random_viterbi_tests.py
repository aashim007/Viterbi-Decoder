#!/usr/bin/env python3

"""
Random Viterbi Test Generator - Fast Version
Generates 10 test cases optimized for quick testing
- 3 long tests (N=1,2,3 with 1 max-length sequence each)
- 7 short tests (N=1-31, mostly < 30 observations)
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

def generate_long_sequence(N, M):
    """
    Generate ONE long sequence for stress testing
    For N=1,2,3 with maximum allowed length
    """
    max_length = (1024-2*N) // N
    sequences = []

    # Use 80-100% of max_length for the single long sequence
    min_len = int(max_length * 0.8)
    length = np.random.randint(min_len, max_length + 1)
    seq = np.random.randint(1, M + 1, size=length).tolist()
    sequences.append(seq)

    return sequences

def generate_short_sequences(N, M, num_sequences=5):
    """
    Generate short sequences for fast testing
    90% of sequences: 2-30 observations
    10% of sequences: 30-100 observations
    """
    sequences = []

    for _ in range(num_sequences):
        # 90% chance of short (2-30), 10% chance of medium (30-100)
        if np.random.random() < 0.9:
            length = np.random.randint(2, 31)  # 2-30
        else:
            max_len = min(100, (1024-2*N) // N)
            length = np.random.randint(30, max_len + 1)  # 30-100

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

def generate_test(test_dir, test_num, N, M, test_type="short"):
    """Generate a complete test case"""
    test_path = Path(test_dir) / f"test_random_{test_num}"
    test_path.mkdir(parents=True, exist_ok=True)

    max_len = (1024-2*N) // N

    # Determine sequences based on test type
    if test_type == "long":
        sequences = generate_long_sequence(N, M)
        num_sequences = 1
        test_label = "[LONG]"
    else:
        num_sequences = np.random.randint(5, 11)  # 5-10 sequences for short tests
        sequences = generate_short_sequences(N, M, num_sequences)
        test_label = "[SHORT]"

    print(f"Generating {test_path.name} {test_label} (N={N:2d}, M={M:2d}, num_seq={num_sequences:2d}, max_len={max_len:4d})")

    write_N_file(test_path / "N.dat", N, M)

    # A matrix: (N+1) x N transition probabilities
    A = generate_random_log_probs(N + 1, N)
    write_matrix_file(test_path / "A.dat", A)

    # B matrix: N x M emission probabilities
    B = generate_random_log_probs(N, M)
    write_matrix_file(test_path / "B.dat", B)

    # Input sequences
    write_input_file(test_path / "input.dat", sequences)

    # Print sequence length statistics
    lengths = [len(s) for s in sequences]
    print(f"Sequence lengths: min={min(lengths)}, max={max(lengths)}, avg={sum(lengths)/len(lengths):.1f}")

    return test_path.name

def main():
    if len(sys.argv) > 1:
        tests_base_dir = sys.argv[1]
    else:
        tests_base_dir = "tests"

    print("="*70)
    print("Random Viterbi Test Generator - Fast Version (10 tests)")
    print("="*70)
    print(f"Output directory: {tests_base_dir}")
    print()
    print("Tests :")
    print("  - 3 LONG tests: N=1,2,3 each with 1 sequence of max_length")
    print("  - 7 SHORT tests: N=1-31, 90% sequences < 30, 10% sequences < 100")
    print()

    generated = []
    test_num = 1

    # Generate 3 long tests with N=1,2,3 (1 sequence each)
    print("Generating LONG tests:")
    for N in [1, 2, 3]:
        M = np.random.randint(2, 8)  # Random M for variety
        test_name = generate_test(tests_base_dir, test_num, N, M, test_type="long")
        generated.append(test_name)
        test_num += 1

    print()
    print("Generating SHORT tests:")

    # Generate 7 short tests with N from 1-31
    for _ in range(7):
        N = np.random.randint(1, 32)  # N can be 1-31
        M = np.random.randint(1, min(32, N + 10))  # M scales with N
        test_name = generate_test(tests_base_dir, test_num, N, M, test_type="short")
        generated.append(test_name)
        test_num += 1

    print()
    print("="*70)
    print(f"Successfully generated {len(generated)} test cases")
    print("="*70)

    # Create a test list file
    test_list_file = Path(tests_base_dir) / "random_tests.txt"
    with open(test_list_file, 'w') as f:
        f.write("# Random test cases\n")
        f.write("# 3 long tests (N=1,2,3 with 1 max sequence each)\n")
        f.write("# 7 short tests (N=1-31 with multiple short sequences)\n")
        for test_name in generated:
            f.write(f"{test_name}\n")

if __name__ == "__main__":
    main()

