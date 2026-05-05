#!/bin/bash
# Automated installer script for Qwen 3.6 35B-A3B optimization project
# Installs all dependencies and sets up the environment

set -e

echo "🚀 Setting up Qwen 3.6 35B-A3B optimization environment..."

# Check for ROCm installation
check_rocm() {
    if [ -d "/opt/rocm" ]; then
        echo "✅ ROCm detected"
        ROCM_AVAILABLE=true
    else
        echo "⚠️  ROCm not found - will install"
        ROCM_AVAILABLE=false
    fi
}

# Install ROCm (if not present)
install_rocm() {
    if [ "$ROCM_AVAILABLE" = false ]; then
        echo "📦 Installing ROCm..."
        # ROCm installation commands for Ubuntu
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y rocm-dev
        else
            echo "❌ Unsupported package manager"
            exit 1
        fi
    fi
}

# Install Docker/Podman
install_container_runtime() {
    echo "📦 Installing container runtime..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y docker.io podman
    fi
}

# Install build tools
install_build_tools() {
    echo "🔧 Installing build tools..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y build-essential cmake git python3 python3-pip
    fi
    
    echo "✨ Build tools installed"
}

# Install llama.cpp with ROCm support
setup_llama_cpp() {
    echo "🎯 Setting up llama.cpp with ROCm support..."
    
    if [ ! -d "llama.cpp" ]; then
        git clone https://github.com/ggerganov/llama.cpp.git
    fi
    
    cd llama.cpp
    mkdir -p build && cd build
    cmake .. -DGGML_CUDA=OFF -DGGML_HIPBLAS=ON -DGGML_METAL=OFF
    make -j$(nproc)
    cd ../..
    
    echo "✅ llama.cpp setup complete"
}

# Main installation routine
main() {
    echo "📋 Checking system requirements..."
    check_rocm
    install_rocm
    install_container_runtime
    install_build_tools
    setup_llama_cpp
    
    echo "✅ Setup complete! All dependencies installed."
}

main