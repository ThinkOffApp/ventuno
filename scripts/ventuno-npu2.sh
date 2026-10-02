#!/bin/bash
# Ventuno Q NPU pass 2: the models we actually use (same GGUFs as the CPU table) through Arduino's llamacpp-npu-runner
# on the Hexagon NPU. Ops the NPU backend lacks fall back to the CPU; the .err keeps llama.cpp's own report. Starts
# after QUICK-DONE so nothing runs beside the CPU pass.
set -u
B=~/boardbench; M=~/models; OUT=$B/results-ventuno-npu2; mkdir -p $M $OUT
log(){ echo "$(date -u +%FT%TZ) $*" | tee -a $OUT/driver.log; }
until grep -q QUICK-DONE $B/results-ventuno-quick/driver.log 2>/dev/null; do sleep 30; done
log "start; $(hostname)"
IMG=ghcr.io/arduino/app-bricks/llamacpp-npu-runner:0.12.1
G1=$(getent group fastrpc | cut -d: -f3); G2=$(getent group dmaheap | cut -d: -f3)
declare -A URL=(
  [Ling-3.0-tiny-Q4_K_M.gguf]=https://huggingface.co/inclusionAI/Ling-3.0-tiny-GGUF/resolve/main/Ling-3.0-tiny-Q4_K_M.gguf
  [Ornith-1.5-9B-Q4_K_M.gguf]=https://huggingface.co/ornith-ai/Ornith-1.5-9B-GGUF/resolve/main/Ornith-1.5-9B-Q4_K_M.gguf )
for f in Ling-3.0-tiny-Q4_K_M.gguf Ornith-1.5-9B-Q4_K_M.gguf Ornith-1.5-35B-A3B-AD-IQ3_XXS-IQ2_S.gguf; do
  d=$M; [ -s ~/models-keep/$f ] && d=~/models-keep
  [ -s $d/$f ] || curl -sfL -o $d/$f "${URL[$f]}" || { log "$f download FAILED"; continue; }
  reps=3; [ $(stat -c %s $d/$f) -gt 8000000000 ] && reps=1
  log "== $f NPU (HTP0, all layers, -r $reps)"
  timeout 1800 docker run --rm --group-add $G1 --group-add $G2 --cpuset-cpus 0-3 --shm-size 2g \
    --device /dev/dma_heap/system --device /dev/fastrpc-cdsp --device /dev/fastrpc-cdsp-secure \
    -v /usr/share/qcom/qcs8300/Qualcomm/QCS8300-RIDE/dsp/cdsp:/lib/dsp/cdsp -v $d:/models:ro \
    -e ADSP_LIBRARY_PATH=/opt/pkg-snapdragon/lib -e LD_LIBRARY_PATH=/opt/pkg-snapdragon/lib -e GGML_HEXAGON_OPBATCH=2048 \
    --entrypoint /opt/pkg-snapdragon/bin/llama-bench $IMG -m /models/$f -dev HTP0 -ngl 99 -t 4 -C 0x0f -fa 1 \
      -p 512 -n 128 -r $reps -o json > $OUT/npu-$f.json 2> $OUT/npu-$f.err
  log "NPU exit=$? $(python3 -c "import json;print(' / '.join(f\"{'pp' if r['n_prompt'] else 'tg'} {r['avg_ts']:.2f}±{r['stddev_ts']:.2f}\" for r in json.load(open('$OUT/npu-$f.json'))))" 2>&1 | tail -1)"
  [ $d = $M ] && rm -f $d/$f
done
log "NPU2-DONE"
