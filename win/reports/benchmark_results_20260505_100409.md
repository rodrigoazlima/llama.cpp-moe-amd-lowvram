# Benchmark Results — 2026-05-05 10:04
- Model: D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
- Repetitions: 3 | Prompt tokens: 512 | Gen tokens: 128

## Baseline (GPU only, f16 KV, mmap on)
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |      1254.64 ┬▒ 40.20 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         60.40 ┬▒ 0.59 |

build: 312cf033 (2500)

## Optimized (MoE CPU offload, q4_0 KV, no-mmap)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        854.82 ┬▒ 7.51 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         25.66 ┬▒ 1.65 |

build: 312cf033 (2500)

