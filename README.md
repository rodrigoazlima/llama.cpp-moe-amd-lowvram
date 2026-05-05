# Qwen3 30B-A3B on AMD GPU — llama.cpp + ROCm

Running Qwen3 MoE models on AMD GPUs (Windows & Linux) using llama.cpp + ROCm.

## 📋 Project Structure

```
.
├── Dockerfile                    # ROCm-enabled container (Linux)
├── setup_installation.sh         # Linux one-command installer
├── unix/scripts/
│   ├── launch_baseline.sh        # Standard configuration
│   ├── launch_optimized.sh       # MoE offloading + KV quantization
│   └── benchmark.sh              # Performance measurement
├── win/scripts/
│   ├── launch_baseline.ps1       # Windows baseline
│   ├── launch_optimized.ps1      # Windows optimized
│   ├── benchmark.ps1             # Windows benchmark
│   └── download_model.ps1        # Model downloader
├── docs/
│   ├── PROJECT_PLAN.md
│   └── Running a 35B AI Model on 6GB VRAM, FAST.md
└── models/                       # Model storage (create manually)
```

## 🔧 Quick Start (Windows)

### 1. Download llama.cpp (ROCm 7.2.1, pre-built)

```powershell
Invoke-WebRequest -Uri "https://repo.radeon.com/rocm/llama.cpp/windows/rocm-rel-7.2.1/llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64.zip" `
    -OutFile "C:\opt\llama-hip\llama-b8407-rocm721.zip"
Expand-Archive "C:\opt\llama-hip\llama-b8407-rocm721.zip" -DestinationPath "C:\opt\llama-hip-amd721\"
```

> ROCm 7.2.1 runtime DLLs are bundled — no separate ROCm install needed.

### 2. Download Model

```powershell
# Requires: pip install huggingface-hub
$env:PYTHONIOENCODING = "utf-8"
huggingface-cli download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-Q4_K_M.gguf `
    --local-dir "D:\opt\models"
```

Or use the helper script:
```powershell
.\win\scripts\download_model.ps1 -Quant UD-Q4_K_M
```

### 3. Launch Server

```powershell
.\win\scripts\launch_baseline.ps1
```

### 4. Test Inference

**PowerShell:**
```powershell
$body = @{
    model    = "qwen"
    messages = @(@{ role = "user"; content = "Hello, what can you do?" })
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://127.0.0.1:8081/v1/chat/completions" `
    -Method POST -ContentType "application/json" -Body $body |
    Select-Object -ExpandProperty choices | ForEach-Object { $_.message.content }
```

**curl:**
```bash
curl http://127.0.0.1:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Hello, what can you do?"}]}'
```

**Streaming (curl):**
```bash
curl http://127.0.0.1:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Write a haiku"}],"stream":true}'
```

### 5. Run Benchmarks

```powershell
.\win\scripts\benchmark.ps1
```

## 🔧 Quick Start (Linux)

### 1. Install Dependencies
```bash
chmod +x setup_installation.sh
./setup_installation.sh
```

### 2. Run Server
```bash
./unix/scripts/launch_baseline.sh /path/to/model.gguf
```

## ⚡ Optimization Flags

### MoE Expert Offloading (`--n-cpu-moe N`)
Offloads expert weights of first N layers to CPU RAM. **Only beneficial when model doesn't fit in VRAM.** If model fits in VRAM, skip this flag — it adds PCIe overhead.

### KV Cache Quantization (`--cache-type-k q4_0 --cache-type-v q4_0`)
Reduces KV cache memory 4×. Allows longer context with less VRAM.

### No Memory Mapping (`--no-mmap`)
Loads entire model into RAM upfront. Reduces latency after load but increases startup time and RAM usage.

### Memory Locking (`--mlock`)
Prevents OS from paging model weights. Improves stability under memory pressure.

## 📊 Benchmark Results (RX 7900 XTX, 24GB VRAM)

Model: Qwen3-Coder-30B-A3B Q4_K_M (17.35 GiB) | llama.cpp b8407 | ROCm 7.2.1

| Config | Prompt Processing | Token Generation |
|--------|------------------:|-----------------:|
| Baseline (GPU, f16 KV, mmap) | **1244 t/s** | **60.7 t/s** |
| Optimized (MoE CPU offload, q4_0 KV, no-mmap) | 858 t/s | 25.2 t/s |

> **Note:** MoE CPU offload hurts performance when the model fits in VRAM. Use baseline config for 24GB+ GPUs.

## 💻 Hardware (Tested)

- **GPU**: AMD Radeon RX 7900 XTX (24GB VRAM)
- **CPU**: AMD Ryzen 9 9900X (12 cores)
- **RAM**: 128GB DDR5
- **OS**: Windows 11 Pro + ROCm 7.2.1 (bundled DLLs)

## 📚 Documentation

- `docs/PROJECT_PLAN.md` — Step-by-step execution plan
- `win/docs/windows-setup.md` — Windows ROCm & llama.cpp download links

## 🧪 Testing & Validation

### Check GPU detection
```powershell
# Windows
$LlamaDir = "C:\opt\llama-hip-amd721\llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
$env:PATH = "$LlamaDir;" + $env:PATH
& "$LlamaDir\llama-server.exe" --list-devices
```

```bash
# Linux
rocm-smi
```

## 🎯 Success Criteria

✅ GPU detected by llama.cpp
✅ Model loads and server starts
✅ API responds to chat completions
✅ Benchmark results captured

## 📝 License

llama.cpp is licensed under the MIT License.

---

**Last Updated**: May 2026
**llama.cpp build**: b8407 (ROCm 7.2.1)
**Tested on**: Qwen3-Coder-30B-A3B, Qwen3.6-35B-A3B
