#!/bin/bash
# Ventuno Q NPU pass: the files App Lab lists for its NPU llama.cpp (Google's Gemma 4 E2B/E4B QAT Q4_0, pinned revisions)
# on the Hexagon NPU through Arduino's llamacpp-npu-runner image, and the same files on the CPU (dotprod build), so the
# two columns use identical GGUFs. Starts only after the CPU rerun says DOTPROD-DONE.
set -u
B=~/boardbench; M=~/models-npu; OUT=$B/results-ventuno-npu; mkdir -p $M $OUT
log(){ echo "$(date -u +%FT%TZ) $*" | tee -a $OUT/driver.log; }
until grep -q DOTPROD-DONE $B/results-ventuno-dotprod/driver.log 2>/dev/null; do sleep 60; done
log "start; $(hostname)"
CPU=~/carwatch-stack/bench/llama.cpp-7fe450e19305b828c199d602c23a8337aaa1f03b/build/bin/llama-bench
IMG=ghcr.io/arduino/app-bricks/llamacpp-npu-runner:0.12.1
G1=$(getent group fastrpc | cut -d: -f3); G2=$(getent group dmaheap | cut -d: -f3)
declare -A URL=(
  [gemma-4-E2B_q4_0-it.gguf]=https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/1894d1fc0a19d86697abd40483f5983c867df03f/gemma-4-E2B_q4_0-it.gguf
  [gemma-4-E4B_q4_0-it.gguf]=https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/99ef3d9bbf819591699ffa9084c4be12db1fbe6c/gemma-4-E4B_q4_0-it.gguf )
for f in gemma-4-E2B_q4_0-it.gguf gemma-4-E4B_q4_0-it.gguf; do
  [ -s $M/$f ] || curl -sfL -o $M/$f "${URL[$f]}" || { log "$f download FAILED"; continue; }
  log "$f $(stat -c %s $M/$f) bytes sha256 $(sha256sum $M/$f | cut -c1-64)"
  log "== $f NPU (HTP0, all layers, 4 threads on cpu0-3)"
  docker run --rm --group-add $G1 --group-add $G2 --cpuset-cpus 0-3 --shm-size 2g \
    --device /dev/dma_heap/system --device /dev/fastrpc-cdsp --device /dev/fastrpc-cdsp-secure \
    -v /usr/share/qcom/qcs8300/Qualcomm/QCS8300-RIDE/dsp/cdsp:/lib/dsp/cdsp -v $M:/models:ro \
    -e ADSP_LIBRARY_PATH=/opt/pkg-snapdragon/lib -e LD_LIBRARY_PATH=/opt/pkg-snapdragon/lib -e GGML_HEXAGON_OPBATCH=2048 \
    --entrypoint /opt/pkg-snapdragon/bin/llama-bench $IMG -m /models/$f -dev HTP0 -ngl 99 -t 4 -C 0x0f -fa 1 \
      -p 512 -n 128 -r 3 -o json > $OUT/npu-$f.json 2> $OUT/npu-$f.err
  log "NPU exit=$? $(python3 -c "import json;print(' / '.join(f\"{'pp' if r['n_prompt'] else 'tg'} {r['avg_ts']:.2f}±{r['stddev_ts']:.2f}\" for r in json.load(open('$OUT/npu-$f.json'))))" 2>&1)"
  log "== $f CPU (dotprod build, 4 threads on cpu0-3)"
  taskset -c 0-3 $CPU -m $M/$f -ngl 0 -t 4 -p 512 -n 128 -r 3 -o json > $OUT/cpu-$f.json 2> $OUT/cpu-$f.err
  log "CPU exit=$? $(python3 -c "import json;print(' / '.join(f\"{'pp' if r['n_prompt'] else 'tg'} {r['avg_ts']:.2f}±{r['stddev_ts']:.2f}\" for r in json.load(open('$OUT/cpu-$f.json'))))" 2>&1)"
done
log "NPU-DONE"
