# Benchmark Results — 2026-05-05 11:39
- Model: D:\opt\models\lmstudio\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
- Repetitions: 3 | Prompt tokens: 512 | Gen tokens: 128

## Baseline (GPU full, f16 KV, mmap on, FA)
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |       289.21 ± 12.17 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         32.06 ± 0.14 |

build: 312cf033 (2500)

## Optimized (MoE CPU offload, q4_0 KV, no-mmap) [low-VRAM only]
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        849.62 ± 2.64 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         26.10 ± 0.34 |

build: 312cf033 (2500)

## KV-quant only (GPU full, q4_0 KV, no-mmap, FA)
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           pp512 |        295.74 ± 8.98 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q4_0 |   q4_0 |  1 |    0 |           tg128 |         32.13 ± 0.07 |

build: 312cf033 (2500)

## q8kv (GPU full, q8_0 KV, no-mmap, FA) — near-lossless, 2x context vs f16
| model                          |       size |     params | backend    | ngl | type_k | type_v | fa | mmap |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -----: | -: | ---: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           pp512 |        294.26 ± 9.56 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |   q8_0 |   q8_0 |  1 |    0 |           tg128 |         32.16 ± 0.13 |

build: 312cf033 (2500)

## highctx (GPU full, q4_0 KV, no-mmap, FA, c=32768) — proxy for 128K context perf
usage: C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64\llama-bench.exe [options]

options:
  -h, --help
  --numa <distribute|isolate|numactl>         numa mode (default: disabled)
  -r, --repetitions <n>                       number of times to repeat each test (default: 5)
  --prio <-1|0|1|2|3>                         process/thread priority (default: 0)
  --delay <0...N> (seconds)                   delay between each test (default: 0)
  -o, --output <csv|json|jsonl|md|sql>        output format printed to stdout (default: md)
  -oe, --output-err <csv|json|jsonl|md|sql>   output format printed to stderr (default: none)
  --list-devices                              list available devices and exit
  -v, --verbose                               verbose output
  --progress                                  print test progress indicators
  --no-warmup                                 skip warmup runs before benchmarking

test parameters:
  -m, --model <filename>                      (default: models/7B/ggml-model-q4_0.gguf)
  -hf, -hfr, --hf-repo <user>/<model>[:quant] Hugging Face model repository; quant is optional, case-insensitive
                                              default to Q4_K_M, or falls back to the first file in the repo if Q4_K_M doesn't exist.
                                              example: unsloth/phi-4-GGUF:Q4_K_M
                                              (default: unused)
  -hff, --hf-file <file>                      Hugging Face model file. If specified, it will override the quant in --hf-repo
                                              (default: unused)
  -hft, --hf-token <token>                    Hugging Face access token
                                              (default: value from HF_TOKEN environment variable)
  -p, --n-prompt <n>                          (default: 512)
  -n, --n-gen <n>                             (default: 128)
  -pg <pp,tg>                                 (default: )
  -d, --n-depth <n>                           (default: 0)
  -b, --batch-size <n>                        (default: 2048)
  -ub, --ubatch-size <n>                      (default: 512)
  -ctk, --cache-type-k <t>                    (default: f16)
  -ctv, --cache-type-v <t>                    (default: f16)
  -t, --threads <n>                           (default: 12)
  -C, --cpu-mask <hex,hex>                    (default: 0x0)
  --cpu-strict <0|1>                          (default: 0)
  --poll <0...100>                            (default: 50)
  -ngl, --n-gpu-layers <n>                    (default: 99)
  -ncmoe, --n-cpu-moe <n>                     (default: 0)
  -sm, --split-mode <none|layer|row>          (default: layer)
  -mg, --main-gpu <i>                         (default: 0)
  -nkvo, --no-kv-offload <0|1>                (default: 0)
  -fa, --flash-attn <0|1>                     (default: 0)
  -dev, --device <dev0/dev1/...>              (default: auto)
  -mmp, --mmap <0|1>                          (default: 1)
  -dio, --direct-io <0|1>                     (default: 0)
  -embd, --embeddings <0|1>                   (default: 0)
  -ts, --tensor-split <ts0/ts1/..>            (default: 0)
  -ot --override-tensor <tensor name pattern>=<buffer type>;...
                                              (default: disabled)
  -nopo, --no-op-offload <0|1>                (default: 0)
  --no-host <0|1>                             (default: 0)

Multiple values can be given for each parameter by separating them with ','
or by specifying the parameter multiple times. Ranges can be given as
'first-last' or 'first-last+step' or 'first-last*mult'.

## ubatch 512 (default)
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           pp512 |        284.73 ± 3.09 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |  1 |           tg128 |         32.18 ± 0.04 |

build: 312cf033 (2500)

## ubatch 1024
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           pp512 |        289.45 ± 4.79 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     1024 |  1 |           tg128 |         32.20 ± 0.14 |

build: 312cf033 (2500)

## ubatch 2048
| model                          |       size |     params | backend    | ngl | n_ubatch | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -------: | -: | --------------: | -------------------: |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           pp512 |        274.83 ± 3.07 |
| qwen3moe 30B.A3B Q4_K - Medium |  17.35 GiB |    30.53 B | ROCm       |  41 |     2048 |  1 |           tg128 |         32.18 ± 0.27 |

build: 312cf033 (2500)

