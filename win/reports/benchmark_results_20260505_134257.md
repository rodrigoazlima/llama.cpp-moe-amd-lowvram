# Benchmark Results -- 2026-05-05 13:43
- Model: D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
- Repetitions: 3 | Prompt tokens: 512 | Gen tokens: 128
- llama.cpp build: b2500 | ROCm 7.2.1 | HSA_ENABLE_SDMA=0

## System Resources (pre-benchmark, model not loaded)
- VRAM: 1.1 GB
- RAM:  36.7 / 125.6 GB
- CPU:  28%
- GPU:  0% (3D)

## Baseline (GPU full, f16 KV, mmap on, FA)
### **Peak VRAM (measured):** 16.25 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB (model 17.35 + KV ~0.07 = ~17.4 GB total)
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |      1241.78 ± 27.82 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         60.00 ± 0.24 |

build: 312cf033 (2500)

## Optimized (MoE CPU offload, q4_0 KV, no-mmap) [low-VRAM only]
### **Peak VRAM (measured):** 7.22 GB
### **Est. KV cache:** q4_0 @ 640 tokens = ~0.02 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        858.27 ± 4.88 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         24.26 ± 0.40 |

build: 312cf033 (2500)

## KV-quant only (GPU full, q4_0 KV, no-mmap, FA)
### **Peak VRAM (measured):** 16.24 GB
### **Est. KV cache:** q4_0 @ 640 tokens = ~0.02 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |       1563.71 ± 2.56 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         59.28 ± 0.62 |

build: 312cf033 (2500)

## q8kv (GPU full, q8_0 KV, no-mmap, FA) -- near-lossless, 2x context vs f16
### **Peak VRAM (measured):** 16.23 GB
### **Est. KV cache:** q8_0 @ 640 tokens = ~0.03 GB
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           pp512 |      1571.12 ± 17.10 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           tg128 |         60.27 ± 0.35 |

build: 312cf033 (2500)

## highctx (GPU full, q4_0 KV, no-mmap, FA, pp=8192) -- 8K context throughput
### **Peak VRAM (measured):** 16.43 GB
### **Est. KV cache:** q4_0 @ 8320 tokens = ~0.22 GB (model 17.35 + KV ~0.22 = ~17.6 GB total)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |          pp8192 |        897.92 ± 0.68 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         59.80 ± 0.18 |

build: 312cf033 (2500)

## largectx (GPU full, f16 KV, no-mmap, FA, pp=8192) -- 8K context, f16 KV
### **Peak VRAM (measured):** 16.83 GB
### **Est. KV cache:** f16 @ 8320 tokens = ~0.89 GB (model 17.35 + KV ~0.89 = ~18.2 GB total)
| model                          |       size |     params | backend    | ngl | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |          pp8192 |        890.81 ± 0.81 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |           tg128 |         60.85 ± 1.05 |

build: 312cf033 (2500)

## maxvram (GPU full, f16 KV, no-mmap, FA, pp=32768) -- 32K context, ~21 GB VRAM
### **Peak VRAM (measured):** 23.72 GB
### **Est. KV cache:** f16 @ 32896 tokens = ~3.51 GB (model 17.35 + KV ~3.51 = ~20.9 GB total)
| model                          |       size |     params | backend    | ngl | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |         pp32768 |        330.05 ± 9.69 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |    0 |           tg128 |         33.63 ± 0.00 |

build: 312cf033 (2500)

## ubatch 512 (default)
### **Peak VRAM (measured):** 22.63 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |      1221.15 ± 56.73 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         59.38 ± 0.30 |

build: 312cf033 (2500)

## ubatch 1024
### **Peak VRAM (measured):** 22.66 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           pp512 |      1227.42 ± 39.08 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           tg128 |         61.81 ± 1.03 |

build: 312cf033 (2500)

## ubatch 2048
### **Peak VRAM (measured):** 16.58 GB
### **Est. KV cache:** f16 @ 640 tokens = ~0.07 GB
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           pp512 |      1226.44 ± 39.43 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           tg128 |         62.03 ± 0.47 |

build: 312cf033 (2500)

## SERVER (Failed to start)
Could not start llama-server on port 53764
