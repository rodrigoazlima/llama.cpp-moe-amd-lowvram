# Benchmark Results — 2026-05-05 11:27
- Model: D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
- Repetitions: 3 | Prompt tokens: 512 | Gen tokens: 128

## Optimized (MoE CPU offload, q4_0 KV, no-mmap)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        362.82 ± 3.93 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         24.47 ± 0.60 |

build: 312cf033 (2500)

## KV-quant only (GPU full, q4_0 KV, no-mmap)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        301.14 ± 5.67 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         32.70 ± 0.02 |

build: 312cf033 (2500)

## Baseline + ubatch 2048
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           pp512 |        293.45 ± 1.34 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           tg128 |         32.93 ± 0.07 |

build: 312cf033 (2500)

