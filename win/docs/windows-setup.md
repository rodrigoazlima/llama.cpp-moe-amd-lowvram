**Here are the latest download links** (as of May 5, 2026) for the key components of your Windows + ROCm + llama.cpp + Qwen 3.6 35B-A3B project.

### 1. AMD ROCm / HIP SDK for Windows (Latest)
- **Official ROCm 7.2.3** (May 2026) — Current stable release.
- Main ROCm Windows page: [https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html](https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html)
- Direct installer links are available on the AMD site (requires EULA acceptance). Check the latest under **HIP SDK for Windows 11**.
- Repository index: [http://repo.radeon.com/rocm/windows/](http://repo.radeon.com/rocm/windows/) (folders for 7.2.1, 7.2, etc.)

**Compatibility matrix** (very important):  
[Windows support matrices](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html)

### 2. llama.cpp Pre-built Binaries for Windows + ROCm

**Recommended options** (in order of preference for your project):

- **AMD Official Validated Builds** (most stable for supported GPUs)  
  Example for ROCm 7.2.1:  
  `https://repo.radeon.com/rocm/llama.cpp/windows/rocm-rel-7.2.1/llama-b8407-windows-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64.zip`  
  Browse all: [https://repo.radeon.com/rocm/llama.cpp/windows/](https://repo.radeon.com/rocm/llama.cpp/windows/)

- **Lemonade SDK Nightly Builds** (freshest, great for latest optimizations)  
  → [https://github.com/lemonade-sdk/llamacpp-rocm/releases/latest](https://github.com/lemonade-sdk/llamacpp-rocm/releases/latest)  
  (Choose Windows + your GPU target: gfx110X for RDNA3 7900 series, gfx120X for RDNA4, etc.)

- **Main llama.cpp GitHub Releases** (includes some ROCm support)  
  → [https://github.com/ggml-org/llama.cpp/releases/latest](https://github.com/ggml-org/llama.cpp/releases/latest)

### 3. Qwen 3.6 35B-A3B GGUF Models (Recommended)

**Best source: unsloth** (high quality imatrix quants, very popular)

- Repository: [https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF)
- Direct tree: [https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main)

**Alternative high-quality quants**:
- bartowski version: [https://huggingface.co/bartowski/Qwen_Qwen3.5-35B-A3B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3.5-35B-A3B-GGUF) (very reliable)

**Recommended quants for low VRAM (6–12GB)**:
- Q4_K_M or Q5_K_M for balance
- Q3_K_M / Q2_K for very low VRAM + heavy offloading

### 4. Additional Useful Links
- ROCm Documentation (latest): [https://rocm.docs.amd.com/en/latest/](https://rocm.docs.amd.com/en/latest/)
- llama.cpp AMD-specific guide: [llama.cpp pre-built binaries](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/advanced/advancedrad/windows/llm/llamacpp.html)

**Quick Tip for Your PROJECT_PLAN.md**:
In the installer script, detect the GPU architecture (`gfx1100`, `gfx1101`, `gfx1200`, etc.) and download the matching prebuilt zip from the AMD repo or Lemonade.

Would you like me to include direct download commands (curl/PowerShell) for the most common combinations (e.g., RX 7900 series + Q4_K_M model)?