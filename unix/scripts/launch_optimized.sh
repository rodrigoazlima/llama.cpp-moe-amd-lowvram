#!/bin/bash
# Optimized launch script - MoE offloading + TurboQuant + memory optimizations

set -e

MODEL_PATH="${1:-$PWD/models/qwen3.6-35b-a3b-Q8_0.gguf}"
GPU_LAYERS=41
CPU_MOE=35
CONTEXT_SIZE=256000
PORT=8080

echo "🚀 Launching Qwen 3.6 35B-A3B - OPTIMIZED Configuration"
echo "📋 Model: $MODEL_PATH"
echo "📋 GPU Layers: $GPU_LAYERS"
echo "📋 CPU MoE: $CPU_MOE (expert offloading enabled)"
echo "📋 Context Size: $CONTEXT_SIZE tokens (4x training context)"
echo "📋 Port: $PORT"

# Check model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Error: Model file not found!"
    echo "💡 Please download the model to: $MODEL_PATH"
    echo "   wget -O $MODEL_PATH <model_url>"
    exit 1
fi

# Check if llama-server exists
if [ ! -f "./llama-server" ] && [ ! -f "./llama.cpp/llama-server" ]; then
    echo "❌ Error: llama-server not found!"
    echo "💡 Please run: ./setup_installation.sh"
    exit 1
fi

# Launch optimized server
LLAMA_PATH="./llama-server"
if [ ! -f "$LLAMA_PATH" ]; then
    LLAMA_PATH="./llama.cpp/llama-server"
fi

echo "⚡ Starting optimized inference server..."
echo "🎯 Key Optimizations:"
echo "   • MoE expert offloading (CPU RAM)"
echo "   • TurboQuant 4-bit keys / 3-bit values"
echo "   • Memory locking (mlock)"
echo "   • No memory mapping (no-mmap)"

$LLAMA_PATH \
    -m "$MODEL_PATH" \
    --n-gpu-layers $GPU_LAYERS \
    --n-cpu-moe $CPU_MOE \
    --turbo-quant 4 \
    --turbo-quant 3 \
    --no-mmap \
    --mlock \
    -c $CONTEXT_SIZE \
    --port $PORT \
    --verbose