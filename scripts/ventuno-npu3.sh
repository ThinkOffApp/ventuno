#!/bin/bash
# Ventuno Q NPU pass 3: our own llama.cpp NPU build (7fe450e, the CPU table's commit, built with Qualcomm's Snapdragon
# toolchain container) on the Hexagon NPU. Gemma 4 E2B Q4_0 first as a check against Arduino's runner (566 / 17.1),
# then the models we use, same GGUFs as the CPU table.
set -u
B=~/boardbench; M=~/models; OUT=$B/results-ventuno-npu3; mkdir -p $M $OUT
log(){ echo "$(date -u +%FT%TZ) $*" | tee -a $OUT/driver.log; }
P=~/llama-npu-7fe450e; export LD_LIBRARY_PATH=$P/lib ADSP_LIBRARY_PATH=$P/lib GGML_HEXAGON_OPBATCH=2048
log "start; $(hostname); NPU build $(basename $P)"
declare -A URL=(
  [gemma-4-E2B_q4_0-it.gguf]=https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/1894d1fc0a19d86697abd40483f5983c867df03f/gemma-4-E2B_q4_0-it.gguf
  [Ling-3.0-tiny-Q4_K_M.gguf]=https://huggingface.co/inclusionAI/Ling-3.0-tiny-GGUF/resolve/main/Ling-3.0-tiny-Q4_K_M.gguf
  [Ornith-1.5-9B-Q4_K_M.gguf]=https://huggingface.co/ornith-ai/Ornith-1.5-9B-GGUF/resolve/main/Ornith-1.5-9B-Q4_K_M.gguf )
for f in gemma-4-E2B_q4_0-it.gguf Ling-3.0-tiny-Q4_K_M.gguf Ornith-1.5-9B-Q4_K_M.gguf Ornith-1.5-35B-A3B-AD-IQ3_XXS-IQ2_S.gguf; do
  d=$M; [ -s ~/models-keep/$f ] && d=~/models-keep; [ -s ~/models-npu/$f ] && d=~/models-npu
  [ -s $d/$f ] || curl -sfL -o $d/$f "${URL[$f]}" || { log "$f download FAILED"; continue; }
  reps=3; [ $(stat -c %s $d/$f) -gt 8000000000 ] && reps=1
  log "== $f NPU (HTP0, all layers, -r $reps)"
  timeout 1800 taskset -c 0-3 $P/bin/llama-bench -m $d/$f -dev HTP0 -ngl 99 -t 4 -fa 1 -p 512 -n 128 -r $reps -o json \
    > $OUT/npu-$f.json 2> $OUT/npu-$f.err
  log "NPU exit=$? $(python3 -c "import json;print(' / '.join(f\"{'pp' if r['n_prompt'] else 'tg'} {r['avg_ts']:.2f}±{r['stddev_ts']:.2f}\" for r in json.load(open('$OUT/npu-$f.json'))))" 2>&1 | tail -1)"
done
log "NPU3-DONE"
