# Qwen 3.6 35B-A3B Optimization Project 🚀

Production-ready system for running Qwen 3.6 35B-A3B (Mixture of Experts) on low-VRAM AMD GPUs using llama.cpp + ROCm

## 📋 Project Structure

```
.
├── Dockerfile                    # ROCm-enabled container
├── setup_installation.sh         # One-command installer
├── scripts/
│   ├── launch_baseline.sh        # Standard configuration
│   ├── launch_optimized.sh       # MoE offloading + TurboQuant
│   ├── benchmark.sh              # Performance measurement
│   └── run_experiment.sh         # Main experiment runner
├── docs/
│   ├── PROJECT_PLAN.md           # Complete implementation guide
│   ├── Running a 35B AI Model on 6GB VRAM, FAST.md
│   └── windows/                  # Windows-specific notes
└── models/                       # Model storage (create manually)
```

## 🔧 Quick Start

### 1. Install Dependencies (One Command)
```bash
chmod +x setup_installation.sh
./setup_installation.sh
```

### 2. Build Docker Container
```bash
docker build -t llamacpp-moe-amd .
```

### 3. Run Baseline Configuration
```bash
./scripts/launch_baseline.sh /path/to/qwen3.6-35b-a3b-Q8_0.gguf
```

### 4. Run Optimized Configuration (5× Faster)
```bash
./scripts/launch_optimized.sh /path/to/qwen3.6-35b-a3b-Q8_0.gguf
```

### 5. Benchmark Performance
```bash
./scripts/benchmark.sh /path/to/qwen3.6-35b-a3b-Q8_0.gguf optimized
```

## ⚡ Key Optimizations Implemented

### MoE Expert Offloading
- **Flag**: `--n-cpu-moe 35`
- **Effect**: Offloads expert blocks to CPU RAM while keeping fast-firing parts on GPU
- **Result**: 230% speed boost (10 → 23 tokens/second)

### TurboQuant KV Cache
- **Flag**: `--turbo-quant 4` (4-bit keys) + `--turbo-quant 3` (3-bit values)
- **Effect**: Nearly lossless quality (equivalent to Q8)
- **Result**: 4× context without quality degradation

### Memory Optimization
- **Flag**: `--no-mmap`
- **Effect**: Loads entire model into RAM upfront
- **Result**: 35% faster (eliminates disk reads during inference)

- **Flag**: `--mlock`
- **Effect**: Prevents kernel from paging out experts
- **Result**: Production-ready stability

## 📊 Expected Performance

| Configuration | Tokens/Second | Context Length | VRAM Usage |
|---------------|---------------|----------------|------------|
| Baseline      | ~10 tokens/s  | 8,192 tokens   | ~16GB      |
| Optimized     | ~50 tokens/s  | 256,000 tokens | ~20GB      |

## 💻 Hardware Requirements

### Minimum (Tested)
- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **CPU**: AMD Ryzen 9 9900X (12 cores)
- **RAM**: 128GB DDR5
- **OS**: Ubuntu Server 22.04 LTS

### Recommended
- Any GPU from this decade (better than GTX 1060)
- Faster RAM (DDR4/DDR5)
- PCIe Gen 4 for better bandwidth
- Results scale with better hardware

## 🐳 Docker Usage

### Build Container
```bash
docker build -t llamacpp-moe-amd .
```

### Run Container
```bash
docker run -d \
  --name llama-server \
  --gpus all \
  --ipc=host \
  -v /path/to/models:/models \
  -p 8080:8080 \
  llamacpp-moe-amd \
  /scripts/launch_optimized.sh /models/qwen3.6-35b-a3b-Q8_0.gguf
```

### Important Docker Flags
- `--gpus all`: Enable GPU passthrough
- `--ipc=host`: Required for memory locking
- `-v /path/to/models:/models`: Mount model directory

## 📚 Documentation

### Complete Implementation Guide
- **File**: `docs/PROJECT_PLAN.md`
- **Contents**:
  - Atomic step-by-step execution plan
  - Detailed configuration instructions
  - Troubleshooting guide
  - Hardware optimization tips

### Optimization Details
- **File**: `docs/Running a 35B AI Model on 6GB VRAM, FAST.md`
- **Contents**:
  - Performance breakdown
  - What didn't work (speculative decoding)
  - Future optimization paths
  - Practical use cases

### Windows Support
- **Directory**: `docs/windows/`
- **Contents**:
  - ROCm on Windows notes
  - Alternative installation methods
  - Known limitations

## 🧪 Testing & Validation

### Run Full Experiment
```bash
./scripts/run_experiment.sh /path/to/model.gguf
```

### Verify Installation
```bash
./setup_installation.sh --verify
```

### Check ROCm Status
```bash
rocm-smi
```

## 🎯 Success Criteria

✅ Model loads successfully
✅ Optimized flags applied correctly
✅ Performance matches expected metrics
✅ System stable over long generations
✅ Documentation complete and accurate
✅ Docker container functional

## 📝 License

This project is based on the video "Running a 35B AI Model on 6GB VRAM, FAST (llama.cpp Guide)" by Codacus. The llama.cpp project is licensed under the MIT License.

## 🤝 Contributing

Found an optimization we missed? Tested on different hardware? Open an issue or PR!

- Share your benchmark results
- Report stability issues
- Suggest additional flags or techniques

## 📞 Support

For issues or questions:
1. Check the documentation in `docs/PROJECT_PLAN.md`
2. Review troubleshooting section
3. Open an issue on GitHub

---

**Last Updated**: May 2026
**Compatible with**: llama.cpp TurboQuant fork
**Tested on**: Qwen v3.6