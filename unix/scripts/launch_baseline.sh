#!/bin/bash
# Baseline launch script - standard configuration without optimizations

set -e

MODEL_PATH="${1:-$PWD/models/qwen3.6-35b-a3b-Q8_0.gguf}"
GPU_LAYERS=20
CONTEXT_SIZE=8192
PORT=8080

echo "🚀 Launching Qwen 3.6 35B-A3B - Baseline Configuration"
echo "📋 Model: $MODEL_PATH"
echo "📋 GPU Layers: $GPU_LAYERS (50/50 split)"
echo "📋 Context Size: $CONTEXT_SIZE tokens"
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

# Launch baseline server
LLAMA_PATH="./llama-server"
if [ ! -f "$LLAMA_PATH" ]; then
    LLAMA_PATH="./llama.cpp/llama-server"
fi

echo "⚡ Starting inference server..."
$LLAMA_PATH \
    -m "$MODEL_PATH" \
    --n-gpu-layers $GPU_LAYERS \
    -c $CONTEXT_SIZE \
    --port $PORT \
    --verbose