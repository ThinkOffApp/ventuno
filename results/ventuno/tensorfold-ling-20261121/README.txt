TensorFold row of the results table: Ling-3.0-tiny Q4_K_M on the VENTUNO Q CPU, 21 November 2026.

Code: TensorFold with the ARM CPU decoder from ashhart/TensorFold#4266, round 2 head ab0e78818
(branch ThinkOffApp/TensorFold:ling-arm-cpu). Tool: ling-cpu-decode, --fast mode, built with
Zig 0.17.0, ReleaseSafe, -Dtarget=aarch64-linux-gnu -Dcpu=baseline+dotprod+sha2.
Model: the same Ling-3.0-tiny-Q4_K_M.gguf as the llama.cpp rows (SHA-256 in provenance.txt).
Run: four threads under taskset -c 0,3,5,7 (the four fast cores), other demo services stopped for
the run, cache warm, model opening excluded. Shape of llama-bench -p 512 -n 128: a 512-token prompt
and 128 generated tokens as separate phases. Repetition 0 is a warmup; repetitions 1 to 3 are
measured.

pp512-tg128.log is the raw log: one BEGIN/END line pair per phase and repetition, with the elapsed
nanoseconds and tokens per second. The table reports the mean of repetitions 1 to 3, timed from
outside the program: 38.4 prompt and 21.2 generation tokens per second.
