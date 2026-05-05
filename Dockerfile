# Dockerfile for Qwen 3.6 35B-A3B Optimization Project with ROCm Support
# Base image with ROCm 5.7 (compatible with AMD GPUs)
FROM rocm/rocm-terminal:5.7.1

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ROCM_PATH=/opt/rocm
ENV PATH=$ROCM_PATH/bin:$ROCM_PATH/hip/bin:$PATH
ENV LD_LIBRARY_PATH=$ROCM_PATH/lib:$ROCM_PATH/hip/lib:$LD_LIBRARY_PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Clone and build llama.cpp with HIPBLAS (ROCm) support
RUN git clone https://github.com/ggerganov/llama.cpp.git /llama.cpp && \
    cd /llama.cpp && \
    mkdir -p build && cd build && \
    cmake .. -DGGML_CUDA=OFF -DGGML_HIPBLAS=ON -DGGML_METAL=OFF && \
    make -j$(nproc) && \
    cd /

# Create model directory
RUN mkdir -p /models

# Copy project scripts
COPY scripts/ /scripts/
COPY setup_installation.sh /setup_installation.sh
RUN chmod +x /scripts/*.sh /setup_installation.sh

# Set working directory
WORKDIR /

# Default command: show help
CMD ["/bin/bash"]