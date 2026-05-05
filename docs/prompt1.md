You are an expert DevOps + LLM inference engineer. Your task is to build a complete, reproducible, production-ready project for running Qwen 3.6 35B-A3B (MoE) on low-VRAM AMD GPUs using llama.cpp + ROCm.

**Requirements:**

- Create **one single comprehensive Markdown file** (`PROJECT_PLAN.md`) that contains the full step-by-step execution plan.
- Break down the entire project into **atomic, sequential, numbered steps** with clear success criteria for each step.
- The plan must cover **everything** needed to go from zero to a fully working experiment.

**Mandatory Deliverables at the end of execution:**
1. A clean project structure with proper folders and files.
2. Automated **installer script** (preferably one-command setup for AMD ROCm).
3. Ready-to-run **launch scripts** for different configurations (baseline vs optimized).
4. **Benchmark script** that automatically measures tokens/sec, VRAM usage, RAM usage, context length, and stability over long generations.
5. Docker / Podman support (recommended for ROCm).
6. Detailed documentation including hardware requirements, expected performance, and troubleshooting.
7. A final working experiment that successfully loads the 35B-A3B model and runs inference with the optimized flags (MoE offloading, TurboQuant, mlock, no-mmap, etc.).

**Key Optimizations to Implement:**
- MoE expert offloading to CPU/RAM
- TurboQuant KV cache (4-bit keys / 3-bit values)
- Memory locking and stability fixes
- no-mmap
- Optimal layer/expert splitting for 6–12GB VRAM cards
- ROCm/HIP specific flags and build instructions

At the end of your execution, confirm that the model is running and provide the benchmark results. Do not stop until the full experiment is working and documented.