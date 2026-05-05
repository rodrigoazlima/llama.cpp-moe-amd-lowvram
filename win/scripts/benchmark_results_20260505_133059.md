# Benchmark Results -- 2026-05-05 13:31
- Model: D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
- Repetitions: 3 | Prompt tokens: 512 | Gen tokens: 128
- llama.cpp build: b2500 | ROCm 7.2.1 | HSA_ENABLE_SDMA=0

## System Resources (pre-benchmark, model not loaded)
- VRAM: 2.51 GB
- RAM:  21.8 / 125.6 GB
- CPU:  48%
- GPU:  6.3% (3D)

## Baseline (GPU full, f16 KV, mmap on, FA)
### **Peak VRAM (measured):** 17.59 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB (model 17.35 + KV ~0.07 = ~17.4 GB total)
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |      1115.72 ± 33.25 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         58.75 ± 0.41 |

build: 312cf033 (2500)

## Optimized (MoE CPU offload, q4_0 KV, no-mmap) [low-VRAM only]
### **Peak VRAM (measured):** 8.62 GB
### **Est. KV cache:** q4_0 @ 640 tokens = ~0.02 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        832.42 ± 9.65 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         27.70 ± 0.85 |

build: 312cf033 (2500)

## KV-quant only (GPU full, q4_0 KV, no-mmap, FA)
### **Peak VRAM (measured):** 17.29 GB
### **Est. KV cache:** q4_0 @ 640 tokens = ~0.02 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |      1485.44 ± 12.07 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         61.70 ± 0.90 |

build: 312cf033 (2500)

## q8kv (GPU full, q8_0 KV, no-mmap, FA) -- near-lossless, 2x context vs f16
### **Peak VRAM (measured):** 17.28 GB
### **Est. KV cache:** q8_0 @ 640 tokens = ~0.03 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           pp512 |       1496.16 ± 6.20 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           tg128 |         63.93 ± 0.44 |

build: 312cf033 (2500)

## highctx (GPU full, q4_0 KV, no-mmap, FA, pp=8192) -- 8K context throughput
### **Peak VRAM (measured):** 17.47 GB
### **Est. KV cache:** q4_0 @ 8320 tokens = ~0.22 GB (model 17.35 + KV ~0.22 = ~17.6 GB total)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |          pp8192 |        859.04 ± 2.96 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         63.57 ± 0.32 |

build: 312cf033 (2500)

## largectx (GPU full, f16 KV, no-mmap, FA, pp=8192) -- 8K context, f16 KV
### **Peak VRAM (measured):** 16.98 GB
### **Est. KV cache:** f16 @ 8320 tokens = ~0.89 GB (model 17.35 + KV ~0.89 = ~18.2 GB total)
| model                          |       size |     params | backend    | ngl | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |          pp8192 |        839.97 ± 1.14 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |           tg128 |         64.71 ± 0.84 |

build: 312cf033 (2500)

## maxvram (GPU full, f16 KV, no-mmap, FA, pp=32768) -- 32K context, ~21 GB VRAM
### **Peak VRAM (measured):** 18.94 GB
### **Est. KV cache:** f16 @ 32896 tokens = ~3.51 GB (model 17.35 + KV ~3.51 = ~20.9 GB total)
| model                          |       size |     params | backend    | ngl | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |         pp32768 |       333.64 ± 12.84 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |           tg128 |         60.56 ± 0.77 |

build: 312cf033 (2500)

## ubatch 512 (default)
### **Peak VRAM (measured):** 16.24 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |      1252.20 ± 42.58 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         60.83 ± 0.35 |

build: 312cf033 (2500)

## ubatch 1024
### **Peak VRAM (measured):** 16.21 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           pp512 |      1248.20 ± 37.74 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           tg128 |         60.36 ± 0.21 |

build: 312cf033 (2500)

## ubatch 2048
### **Peak VRAM (measured):** 16.23 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           pp512 |      1257.42 ± 43.02 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           tg128 |         60.51 ± 0.23 |

build: 312cf033 (2500)

## SERVER (Failed to start)
Could not start llama-server on port 56237
