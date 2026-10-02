#!/bin/bash
# Ventuno Q, quick pass for the 3 big models: dotprod CPU build, 4 threads on cpu0-3, pp512/tg128 like the Pi table,
# ONE repetition (not 3) and no 8-thread pass or quality checks, to get the table out fast. Starts after NPU-DONE.
set -u
B=~/boardbench; M=~/models; OUT=$B/results-ventuno-quick; mkdir -p $M $OUT
log(){ echo "$(date -u +%FT%TZ) $*" | tee -a $OUT/driver.log; }
until grep -q NPU-DONE $B/results-ventuno-npu/driver.log 2>/dev/null; do sleep 30; done
CPU=~/carwatch-stack/bench/llama.cpp-7fe450e19305b828c199d602c23a8337aaa1f03b/build/bin/llama-bench
declare -A URL=(
  [Qwen3.6-35B-A3B-UD-Q3_K_S.gguf]=https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q3_K_S.gguf
  [Qwen3.8-27B-UD-Q2_K_XL.gguf]=https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-UD-Q2_K_XL.gguf )
for f in Ornith-1.5-35B-A3B-AD-IQ3_XXS-IQ2_S.gguf Qwen3.6-35B-A3B-UD-Q3_K_S.gguf Qwen3.8-27B-UD-Q2_K_XL.gguf; do
  p=$M/$f; [ -s ~/models-keep/$f ] && p=~/models-keep/$f
  [ -s $p ] || curl -sfL -o $p "${URL[$f]}" || { log "$f download FAILED"; continue; }
  log "== $f ($(stat -c %s $p) bytes)"
  taskset -c 0-3 $CPU -m $p -ngl 0 -t 4 -p 512 -n 128 -r 1 -o json > $OUT/cpu-$f.json 2> $OUT/cpu-$f.err
  log "CPU exit=$? $(python3 -c "import json;print(' / '.join(f\"{'pp' if r['n_prompt'] else 'tg'} {r['avg_ts']:.2f}\" for r in json.load(open('$OUT/cpu-$f.json'))))" 2>&1)"
  [ $p = $M/$f ] && rm -f $p
done
log "QUICK-DONE"
