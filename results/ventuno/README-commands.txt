Ventuno Q NPU commands, 2 Oct 2026 (exact):
Arduino runner (results-ventuno-npu): docker run llamacpp-npu-runner:0.12.1 ... llama-bench -m F -dev HTP0 -ngl 99 -t 4 -C 0x0f -fa 1 -p 512 -n 128 -r 3   (--cpuset-cpus 0-3, GGML_HEXAGON_OPBATCH=2048)  -> see ventuno-npu.sh
Our build, Gemma (results-ventuno-npu3): taskset -c 0-3 llama-npu-7fe450e/bin/llama-bench -m F -dev HTP0 -ngl 99 -t 4 -fa 1 -p 512 -n 128 -r 3   (no -C mask, no container, GGML_HEXAGON_OPBATCH=2048) -> see ventuno-npu3.sh
  NOTE: runtime settings are NOT identical to the Arduino run (container vs host; -C 0x0f vs taskset). 566 -> 698 is not attributable to the build alone.
Our build, Ling: GGML_HEXAGON_DEVICES=3, -dev HTP0/HTP1/HTP2, -r 1 (by hand; log ling-npu-3.err; 2 sessions crashed: ling-npu-2.err)
Our build, Ornith 9B: GGML_HEXAGON_DEVICES=4, -dev HTP0/HTP1/HTP2/HTP3, -r 1 (by hand; log orn-npu-4.err; 3 sessions crashed: orn-npu-3.err)
35B: single session, OOM-killed at 11.4 GB anon RSS, see oom-35b-kernel.log
