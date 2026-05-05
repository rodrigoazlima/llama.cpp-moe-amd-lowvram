#!/bin/bash
# Comprehensive benchmarking script for Qwen 3.6 35B-A3B
# Measures tokens/sec, VRAM usage, RAM usage, and stability

set -e

MODEL_PATH="${1:-$PWD/models/qwen3.6-35b-a3b-Q8_0.gguf}"
CONFIG="${2:-optimized}"  # baseline or optimized
DURATION=60  # seconds
OUTPUT_FILE="benchmark_results_${CONFIG}_$(date +%Y%m%d_%H%M%S).txt"

echo "📊 Starting Qwen 3.6 35B-A3B Benchmark"
echo "📋 Model: $MODEL_PATH"
echo "📋 Configuration: $CONFIG"
echo "📋 Duration: $DURATION seconds"
echo "📋 Output: $OUTPUT_FILE"

# Check model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Error: Model file not found!"
    exit 1
fi

# Start benchmark
echo "🚀 Starting benchmark..." | tee "$OUTPUT_FILE"
echo "Timestamp: $(date)" | tee -a "$OUTPUT_FILE"
echo "System Info: $(uname -a)" | tee -a "$OUTPUT_FILE"

# Get initial system stats
echo -e "\n📈 Initial System Stats:" | tee -a "$OUTPUT_FILE"
free -h | tee -a "$OUTPUT_FILE"
if command -v rocm-smi &> /dev/null; then
    rocm-smi --showtemp --showmeminfo vram | tee -a "$OUTPUT_FILE"
fi

# Run appropriate configuration
if [ "$CONFIG" = "baseline" ]; then
    echo -e "\n📋 Running BASELINE configuration..." | tee -a "$OUTPUT_FILE"
    ./scripts/launch_baseline.sh "$MODEL_PATH" &
elif [ "$CONFIG" = "optimized" ]; then
    echo -e "\n📋 Running OPTIMIZED configuration..." | tee -a "$OUTPUT_FILE"
    ./scripts/launch_optimized.sh "$MODEL_PATH" &
else
    echo "❌ Error: Invalid configuration. Use 'baseline' or 'optimized'"
    exit 1
fi

SERVER_PID=$!
sleep 5  # Wait for server to start

# Test inference performance
echo -e "\n🧪 Testing inference performance..." | tee -a "$OUTPUT_FILE"

# Simple benchmark using curl
START_TIME=$(date +%s)
TOKEN_COUNT=0

# Run for specified duration
while [ $(( $(date +%s) - START_TIME )) -lt $DURATION ]; do
    # Send test prompt
    PROMPT="The quick brown fox jumps over the lazy dog. This is a test of the inference system."
    RESPONSE=$(curl -s -X POST http://localhost:8080/completion \
        -H "Content-Type: application/json" \
        -d '{"prompt": "'"$PROMPT"'", "n_predict": 50, "temperature": 0.7}')

    # Count tokens in response
    RESPONSE_TOKENS=$(echo "$RESPONSE" | wc -w)
    TOKEN_COUNT=$((TOKEN_COUNT + RESPONSE_TOKENS))
    sleep 1
done

# Calculate performance metrics
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
TOKENS_PER_SEC=$(echo "scale=2; $TOKEN_COUNT / $ELAPSED" | bc)

echo -e "\n📊 Performance Results:" | tee -a "$OUTPUT_FILE"
echo "   • Tokens Generated: $TOKEN_COUNT" | tee -a "$OUTPUT_FILE"
echo "   • Time Elapsed: $ELAPSED seconds" | tee -a "$OUTPUT_FILE"
echo "   • Tokens/Second: $TOKENS_PER_SEC" | tee -a "$OUTPUT_FILE"

# Get final system stats
echo -e "\n📈 Final System Stats:" | tee -a "$OUTPUT_FILE"
free -h | tee -a "$OUTPUT_FILE"
if command -v rocm-smi &> /dev/null; then
    rocm-smi --showtemp --showmeminfo vram | tee -a "$OUTPUT_FILE"
fi

# Cleanup
kill $SERVER_PID 2>/dev/null || true

echo -e "\n✅ Benchmark complete! Results saved to $OUTPUT_FILE"