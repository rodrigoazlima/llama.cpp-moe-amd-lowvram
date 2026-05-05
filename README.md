cr# Running 35B AI Models on 24GB VRAM - llama.cpp Optimization Project

🚀 **Run a 35B parameter AI model on just 24GB VRAM** 🚀

This project demonstrates how to run large language models locally on low-end hardware using llama.cpp with advanced optimization techniques. Despite the seemingly impossible hardware constraints, with the right configuration, you can achieve usable performance for AI applications.

---

## 🎯 Results Summary

- **Model**: Qwen 3.6 35B A3B (35 billion parameters, Mixture of Experts)
- **GPU**: NVIDIA GTX 1060 (6GB VRAM, 8-year-old hardware)
- **CPU**: Intel i3-8100 (4 cores, no hyperthreading)
- **RAM**: 24GB DDR4
- **Performance**: **17 tokens/second**
- **Context Window**: **256,000 tokens** (4× the model's training context)
- **VRAM Usage**: 5.9/6GB (98% utilization)

---

## 📋 Key Optimizations: The 5 Critical Flags

All optimizations are achieved through just 5 command-line flags in llama.cpp:

### 1. **`--n-cpu-moe 35`** (MoE Offloading)
- Default baseline (splitting layers 50/50): **3 tokens/second**
- Offloads expert blocks to CPU RAM while keeping fast-firing parts on GPU
- **Result**: 230% speed boost (**10 tokens/second**)
- Expert blocks are "dead weight" on GPU but "cheap rent" in RAM

### 2. **`--no-mmap`** (Memory Mapping)
- Loads entire model into RAM upfront instead of OS page-fault paging
- Eliminates disk reads during inference
- **Result**: 35% faster (**13.5 tokens/second**)

### 3. **Reduce `--n-cpu-moe` from 41 to 35**
- Pulls 6 additional expert layers back onto GPU
- Utilizes free VRAM (from 4GB to 5.5GB used)
- More work on fast chip, less PCIe bus traffic
- **Final Result**: **17 tokens/second** (faster than reading speed!)

### 4. **`--turbo-quant 4`** (Key Quantization)
- Google DeepMind's TurboQuant: 4-bit keys with random rotation
- Nearly lossless quality (equivalent to Q8)
- Enables 4× context without quality degradation

### 5. **`--turbo-quant 3`** (Value Quantization)
- 3-bit values (asymmetric with keys)
- Takes advantage of 8:1 grouped query attention ratio
- Keys can handle heavier compression than values

---

## 💻 Hardware Stack

### Minimum Configuration (Tested)
- **GPU**: NVIDIA GTX 1060 6GB (PCIe Gen 3, 8 years old)
- **CPU**: Intel i3-8100 (4 cores)
- **RAM**: 24GB DDR4
- **OS**: Proxmox → LXC → Docker

### Recommended Stack
- Any GPU from this decade (better than 1060)
- Faster RAM (DDR4/DDR5)
- PCIe Gen 4 for better bandwidth
- Results scale with better hardware

---

## 🐳 Quick Start: Docker Command

```bash
docker run -d \
  --name llama-server \
  --gpus all \
  --ipc=host \
  -v /path/to/models:/models \
  -p 8080:8080 \
  llamacpp-moe-amd-lowvram \
  llama-server \
  -m /models/qwen3.6-35b-a3b-Q8_0.gguf \
  --n-gpu-layers 41 \
  --n-cpu-moe 35 \
  --no-mmap \
  --mlock \
  --turbo-quant 4 \
  --turbo-quant 3 \
  -c 256000 \
  --port 8080
```

### Critical System Configuration

For stability, enable memory locking in three places:

1. **LXC Container**: Enable `privileged` or `cap_ipc_lock`
2. **Docker**: Add `--ipc=host` capability
3. **llama.cpp**: Use `--mlock` flag

Without all three, the kernel may page out experts under memory pressure, causing random slowdowns.

---

## 📊 Performance Breakdown

### Baseline (Naive Approach)
```bash
llama-server -m model.gguf --n-gpu-layers 20
```
- **Speed**: 3 tokens/second
- **Problem**: All layer experts travel across PCIe bus
- **Result**: Unusable "satellite phone" speeds

### After Optimization
```bash
llama-server -m model.gguf \
  --n-gpu-layers 41 \
  --n-cpu-moe 35 \
  --no-mmap \
  --mlock \
  --turbo-quant 4 \
  --turbo-quant 3 \
  -c 256000
```
- **Speed**: 17 tokens/second (5.7× faster)
- **Context**: 256K tokens (4× training context)
- **Quality**: Nearly identical to full precision
- **Stability**: Production-ready (no degradation over days)

---

## 🔍 What Didn't Work: Speculative Decoding

### Attempted Optimization
- **Technique**: Run Qwen 3.5 800M as "drafter" model alongside 35B target
- **Theory**: Small model guesses 8 tokens, big model verifies in batch
- **Expected**: 2-4× speedup

### Reality
- **Speed**: Dropped from 17 → 11 tokens/second (slower!)
- **Accuracy**: 65% acceptance rate (decent)
- **Why It Failed**:
  1. **Mixture of Experts**: Each token picks different experts → memory thrashing across PCIe
  2. **SSM Layers**: 30/40 layers are State Space Models (sequential, can't parallelize)
  3. **Expert Loading**: Dominates verification time, batching doesn't help

### Future Hope
- **Dflash**: Block diffusion drafter for dense models
- Works with Qwen 3.6 27B dense version
- Potential path to 25 tokens/second

---

## 📚 Useful Resources

- **Model**: [Qwen 3.6 35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) (Hugging Face)
- **Paper**: [TurboQuant: Aggressive Quantization with Rotation](https://arxiv.org/abs/...) 
- **Fork**: [llama.cpp TurboQuant](https://github.com/TheTom/llama-cpp-turboquant)
- **Video**: [YouTube Guide](https://www.youtube.com/watch?v=8F_5pdcD3HY)

---

## 💡 Practical Use Cases

What would you run on this setup?

- ✅ **Codebase Q&A**: Feed entire repositories as context
- ✅ **Long Document Analysis**: Summarize books or reports
- ✅ **Local Agents**: Privacy-focused AI assistants
- ✅ **Offline Development**: No cloud costs or API limits

### Context Window Examples
| Context Size | Approximate Content |
|-------------|-------------------|
| 64K tokens | Medium article (~48k words) |
| 128K tokens | Technical manual (~96k words) |
| 256K tokens | Small book (~200k words) |

---

## 🎓 Key Insights

1. **Defaults Matter**: The hardware isn't the bottleneck—the defaults are
2. **MoE Changes Everything**: Mixture of Experts enables massive compression
3. **Memory > Compute**: Keeping experts in RAM beats GPU compute for this workload
4. **TurboQuant is Magic**: 3-4 bit quantization with near-lossless quality
5. **Hardware Floor, Not Ceiling**: Better hardware will exceed these results

---

## 🤔 Honest Assessment

> "If your setup is better than this 8-year-old rig, your numbers will come out better than mine. The point is that this rig is a **floor**, not a ceiling."

Most of the work is already done. You just have to know which flags to set.

---

## 📝 License

This guide is based on the video "Running a 35B AI Model on 6GB VRAM, FAST (llama.cpp Guide)" by Codacus. The llama.cpp project is licensed under the MIT License.

---

## ⭐ Contributing

Found an optimization we missed? Tested on different hardware? Open an issue or PR!

- Share your benchmark results
- Report stability issues
- Suggest additional flags or techniques

---

**Last Updated**: May 2026  
**Compatible with**: llama.cpp TurboQuant fork  
**Tested on**: Qwen v3.6