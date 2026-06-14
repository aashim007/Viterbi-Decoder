#!/usr/bin/env python3
"""
Viterbi Decoder Output Generator (Float32 Version)
Computes expected hex values for Viterbi decoder outputs using fp32
"""

import numpy as np
import struct
import sys

def read_N_file(filename):
    """Read N and M from N.dat file"""
    with open(filename, 'r') as f:
        N = int(f.readline().strip(), 16) # Updated to interpret as hex values only
        M = int(f.readline().strip(), 16)
    return N, M

def read_A_file(filename, N):
    """Read (N+1) x N transition probability matrix in log form"""
    A = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                # Convert hex string to float
                hex_val = int(line, 16)
                float_val = struct.unpack('!f', struct.pack('!I', hex_val))[0]
                # Validation check for log probabilities
                if float_val > 0:
                    print(f"ERROR: Positive log probability detected: {float_val}")
                    print(f"Log probabilities must be negative (hex: {line})")
                    sys.exit(1)
                A.append(float_val)

    # Reshape to (N+1) x N matrix - using float32
    A = np.array(A, dtype=np.float32).reshape(N+1, N)
    return A

def read_B_file(filename, N, M):
    """Read N x M emission probability matrix in log form"""
    B = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                hex_val = int(line, 16)
                float_val = struct.unpack('!f', struct.pack('!I', hex_val))[0]
                # Validation check for log probabilities
                if float_val > 0:
                    print(f"ERROR: Positive log probability detected: {float_val}")
                    print(f"Log probabilities must be negative (hex: {line})")
                    sys.exit(1)
                B.append(float_val)

    # Reshape to N x M matrix - using float32
    B = np.array(B, dtype=np.float32).reshape(N, M)
    return B

def read_input_file(filename):
    """Read input observation sequences (handles both decimal and hex formats)"""
    sequences = []
    current_seq = []

    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                # Try to parse as hex first, then decimal
                try:
                    if line.upper().startswith('0X'):
                        val = int(line, 16)
                    elif all(c in '0123456789ABCDEFabcdef' for c in line):
                        # Looks like hex
                        val = int(line, 16)
                    else:
                        # Must be decimal
                        val = int(line)
                except ValueError:
                    print(f"Error: Could not parse value: {line}")
                    continue

                if val == 0xFFFFFFFF:
                    if current_seq:
                        sequences.append(current_seq)
                        current_seq = []
                elif val == 0:
                    break
                else:
                    current_seq.append(val)

    return sequences

def float_to_hex(f):
    """Convert float to 32-bit hex string (lowercase, 8 digits)"""
    packed = struct.pack('!f', f)
    hex_val = struct.unpack('!I', packed)[0]
    return f"{hex_val:08x}"

def viterbi_decode(observations, A, B, N, M):
    """
    Viterbi algorithm implementation using float32 precision

    Args:
        observations: List of observations (1-indexed)
        A: Transition probability matrix (N+1) x N in log form (float32)
        B: Emission probability matrix N x M in log form (float32)
        N: Number of states
        M: Number of observations

    Returns:
        best_path: Most likely state sequence (1-indexed)
        best_prob: Log probability of best path (float32)
    """
    T = len(observations)

    # Use float32 for all calculations (matching hardware precision)
    V = np.zeros((T, N), dtype=np.float32)
    Path = np.zeros((T, N), dtype=np.int32)

    # Initialization step (t=0)
    obs_idx = observations[0] - 1  # Convert to 0-indexed
    for s in range(N):
        # log P(q_s | q_start) + log P(o_1 | q_s)
        V[0, s] = A[0, s] + B[s, obs_idx]
        Path[0, s] = 0

    # Recursion step
    for t in range(1, T):
        obs_idx = observations[t] - 1  # Convert to 0-indexed
        for s in range(N):
            # For each state s at time t, find best previous state
            max_prob = np.float32(-np.inf)
            best_prev = 0

            for prev_s in range(N):
                # All operations in float32
                prob = V[t-1, prev_s] + A[prev_s+1, s] + B[s, obs_idx]

                if prob > max_prob:
                    max_prob = prob
                    best_prev = prev_s

            V[t, s] = max_prob
            Path[t, s] = best_prev

    # Termination: find best final state
    best_final_state = np.argmax(V[T-1])
    best_prob = V[T-1, best_final_state]

    # Backtrack to find best path
    best_path = [0] * T
    best_path[T-1] = best_final_state + 1  # Convert to 1-indexed

    for t in range(T-2, -1, -1):
        prev_state = Path[t+1, best_path[t+1] - 1]
        best_path[t] = prev_state + 1  # Convert to 1-indexed

    return best_path, best_prob

def generate_output(sequences, A, B, N, M, output_filename):
    """Generate output file with Viterbi decoding results"""
    with open(output_filename, 'w') as f:
        for seq in sequences:
            best_path, best_prob = viterbi_decode(seq, A, B, N, M)

            # Write state sequence (1-indexed) as 8-digit hex
            for state in best_path:
                f.write(f"{state:08x}\n")

            # Write probability in hex format (lowercase, 8 digits)
            prob_hex = float_to_hex(best_prob)
            f.write(f"{prob_hex}\n")

            # Write end marker (lowercase, 8 digits)
            f.write("ffffffff\n")

        # Write final terminator (8 digits)
        f.write("00000000\n")

def main():
    if len(sys.argv) < 6:
        print("Usage: python viterbi_output_generator.py N.dat A.dat B.dat input.dat [output.dat]")
        print("  Default output filename: golden_output.dat")
        sys.exit(1)

    n_file = sys.argv[1]
    a_file = sys.argv[2]
    b_file = sys.argv[3]
    input_file = sys.argv[4]
    output_file = sys.argv[5] if len(sys.argv) > 5 else "golden_output.dat"

    print("="*70)
    print("Viterbi Decoder Output Generator (Float32)")
    print("="*70)
    print("Reading input files...")
    N, M = read_N_file(n_file)
    print(f"  N (states) = {N}")
    print(f"  M (observations) = {M}")

    A = read_A_file(a_file, N)
    print(f"  Transition matrix A: {A.shape} (dtype: {A.dtype})")

    B = read_B_file(b_file, N, M)
    print(f"  Emission matrix B: {B.shape} (dtype: {B.dtype})")

    sequences = read_input_file(input_file)
    print(f"  Number of input sequences: {len(sequences)}")

    print("\nRunning Viterbi algorithm (float32 precision)...")
    generate_output(sequences, A, B, N, M, output_file)
    
    print("="*70)
    print(f"✓ Golden output written to: {output_file}")
    print("="*70)

if __name__ == "__main__":
    main()

