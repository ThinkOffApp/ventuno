#!/bin/bash
# Build llama.cpp with the Hexagon NPU backend for the Arduino VENTUNO Q (Qualcomm Dragonwing IQ8, HTP v75).
# Runs on any x86_64 Linux host with Docker; uses Qualcomm's public Snapdragon toolchain container, as in
# llama.cpp's docs/backend/snapdragon/linux.md. Output: pkg-linux-<ref>.tgz, ready to unpack on the board.
set -euo pipefail
REF=${1:-7fe450e19305b828c199d602c23a8337aaa1f03b}   # the commit all our numbers were measured with
W=${WORK:-$PWD/llama.cpp-$REF}
if [ ! -d "$W/.git" ]; then
  git init -q "$W"; git -C "$W" fetch -q --depth 1 https://github.com/ggml-org/llama.cpp "$REF"; git -C "$W" checkout -q --detach FETCH_HEAD
fi
docker run --rm -u "$(id -u):$(id -g)" -v "$W":/workspace -w /workspace --platform linux/amd64 \
  ghcr.io/snapdragon-toolchain/arm64-linux:v0.7 bash -c \
  "cp docs/backend/snapdragon/CMakeUserPresets.json . && cmake --preset arm64-linux-snapdragon-release -B build-snapdragon \
   && cmake --build build-snapdragon -j \$(nproc) && cmake --install build-snapdragon --prefix pkg-linux"
tar czf "pkg-linux-${REF:0:7}.tgz" -C "$W/pkg-linux" .
echo "built pkg-linux-${REF:0:7}.tgz"
