#!/bin/bash

export TB=/home/shakti/Work/Project/ViterbiDecoder/tb
export SRC=/home/shakti/Work/Project/ViterbiDecoder/src
export RUN=/home/shakti/Work/Project/ViterbiDecoder/run
export BUILD=$RUN/build

# Create build directory
mkdir -p $BUILD

echo "Compiling testbench..."
bsc -sim -bdir $BUILD -simdir $BUILD \
    -p $TB:$SRC:.:%/Libraries \
    -g mkTbViterbiDecoder -u $TB/tbViterbiDecoder.bsv

echo "Linking..."
bsc -sim -bdir $BUILD -simdir $BUILD \
    -e mkTbViterbiDecoder -o tbViterbiDecoder.exe

echo "Running simulation..."
./tbViterbiDecoder.exe

