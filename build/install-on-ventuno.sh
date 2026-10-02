#!/bin/bash
# Unpack the NPU build on the VENTUNO Q and check that it sees the NPU. No sudo, nothing outside this folder changes.
set -euo pipefail
PKG=${1:?usage: install-on-ventuno.sh pkg-linux-7fe450e.tgz}; DIR=${2:-$HOME/llama-npu}
mkdir -p "$DIR" && tar xzf "$PKG" -C "$DIR"
# The board ships libcdsprpc.so.1 but not the unversioned name the backend dlopens: link it inside our own lib dir.
ln -sf /usr/lib/aarch64-linux-gnu/libcdsprpc.so.1 "$DIR/lib/libcdsprpc.so"
LD_LIBRARY_PATH="$DIR/lib" ADSP_LIBRARY_PATH="$DIR/lib" "$DIR/bin/llama-bench" --list-devices
echo
echo "Run, e.g.: LD_LIBRARY_PATH=$DIR/lib ADSP_LIBRARY_PATH=$DIR/lib taskset -c 0-3 $DIR/bin/llama-bench -m model.gguf -dev HTP0 -ngl 99 -t 4 -fa 1"
echo "Models over ~3.5 GB: GGML_HEXAGON_DEVICES=4 ... -dev HTP0/HTP1/HTP2/HTP3"
