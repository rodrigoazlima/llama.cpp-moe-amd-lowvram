.\win\scripts\benchmark262k.ps1 -Force            
  [FORCE] ladder: est. 23.25 GB — proceeding at risk (24 GB limit).

=== 8K prompt ===
    pp=8192  n=128  reps=2  ctx=8320  KV=q4_0 (0.22 GB)  est.VRAM=16.47 GB  ETA=24s
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |          pp8192 |       881.50 ± 15.78 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         60.23 ± 0.03 |
    Peak VRAM: 16.69 GB

=== 32K prompt ===
    pp=32768  n=128  reps=2  ctx=32896  KV=q4_0 (0.88 GB)  est.VRAM=17.13 GB  ETA=3 min
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |         pp32768 |        342.56 ± 0.11 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         59.70 ± 0.37 |
    Peak VRAM: 17.94 GB

=== 64K prompt ===
    pp=65536  n=32  reps=2  ctx=65568  KV=q4_0 (1.75 GB)  est.VRAM=18 GB  ETA=10 min
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |         pp65536 |        171.03 ± 0.05 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |            tg32 |         59.83 ± 0.50 |
    Peak VRAM: 19.99 GB

=== 128K prompt ===
    pp=131072  n=32  reps=2  ctx=131104  KV=q4_0 (3.5 GB)  est.VRAM=19.75 GB  ETA=27 min
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |        pp131072 |         74.31 ± 0.00 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |            tg32 |         59.88 ± 0.38 |
    Peak VRAM: 23.22 GB

=== 192K prompt ===
    pp=196608  n=32  reps=2  ctx=196640  KV=q4_0 (5.25 GB)  est.VRAM=21.5 GB  ETA=55 min
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |        pp196608 |         34.79 ± 0.36 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |            tg32 |         43.41 ± 0.87 |
    Peak VRAM: 23.82 GB

=== 262K prompt (max) ===
    pp=262016  n=32  reps=2  ctx=262048  KV=q4_0 (7 GB)  est.VRAM=23.25 GB  ETA=1.6 hr
    (broken)