# Model Selection Guide

## Selection Criteria

FamilyAI uses carefully selected open-source models optimized for Jetson Thor's hardware capabilities.

## Code Assistant Models

### Qwen2.5-Coder-32B-Instruct
**Use Cases**:
- Code completion in IDEs
- Function generation
- Bug fixing
- Code refactoring
- Documentation generation

**Specifications**:
- Parameters: 32B
- Context: 32K tokens
- Memory (INT4): ~18GB
- Performance: 73.7 on Aider (GPT-4o level)

**Benchmarks**:
- HumanEval: 92.7%
- MBPP: 88.3%
- Aider: 73.7

### Qwen3-Coder-30B-A3B-Instruct
**Use Cases**:
- Multi-file code analysis
- Repository-level understanding
- Long-context coding tasks
- Browser automation
- AI agent workflows

**Specifications**:
- Parameters: 30B total, 3.3B active (MoE)
- Context: 256K native, 1M extended
- Memory (INT4): ~15GB
- Activation: 11% of parameters per token

**Advantages**:
- Lower memory footprint than dense models
- Faster inference due to sparse activation
- Excellent long-context capability

## Chat Models

### Qwen3-32B-Instruct
**Use Cases**:
- Complex reasoning
- Creative writing
- Math problems
- Detailed explanations

**Performance**:
- Equivalent to Qwen2.5-72B
- 50% parameter efficiency gain
- MMLU: 85.3

### Qwen3-8B-Instruct
**Use Cases**:
- General conversation
- Information lookup
- Language translation
- Summarization

**Performance**:
- Equivalent to Qwen2.5-14B
- MMLU: 78.1
- Speed: ~150-200 tok/s on Thor

### Qwen3-4B-Instruct
**Use Cases**:
- Quick Q&A
- Simple queries
- Fast interactions
- High concurrency scenarios

**Performance**:
- Equivalent to Qwen2.5-7B
- MMLU: 70.4
- Speed: ~300-400 tok/s on Thor

## Vision Model

### Qwen2-VL-7B-Instruct
**Use Cases**:
- Image description
- Visual Q&A
- OCR
- Multi-image comparison

**Specifications**:
- Parameters: 7B
- Context: 32K tokens
- Memory (INT4): ~4GB

**Benchmarks**:
- DocVQA: 94.5
- ChartQA: 83.0
- TextVQA: 84.3

## Speech Models

### Whisper-Small
**Use Cases**:
- Speech recognition
- Multi-language transcription
- Audio file processing

**Specifications**:
- Parameters: 244M
- Languages: 99+
- Real-time factor: <0.3

### Piper TTS
**Use Cases**:
- Text-to-speech synthesis
- Voice assistant responses

**Specifications**:
- Parameters: <100M
- Voices: Multiple languages
- Latency: <100ms

## Quantization Strategy

### INT4 AWQ
**Advantages**:
- 4x memory reduction vs FP16
- ~2x throughput increase
- <1% quality degradation
- Native support on Blackwell GPUs

**Trade-offs**:
- Slight precision loss (acceptable for most tasks)
- Requires pre-quantized models

## Memory Budget

| Model | FP16 | INT4 | Saved |
|-------|------|------|-------|
| Qwen3-32B | ~64GB | ~18GB | 72% |
| Qwen3-8B | ~16GB | ~4GB | 75% |
| Qwen3-4B | ~8GB | ~2GB | 75% |

**Total on Thor**: ~40GB active, ~80GB available for batching

## Model Switching Strategy

### Hot-Swappable: Code Assistants
- Only load one at a time
- Switch based on task requirements
- Saves ~18GB memory

### Always Running: Chat Models
- All three sizes loaded
- Instant routing
- Better user experience

## Future Upgrades

### Planned
- Qwen3-Coder dense models (when released)
- Qwen3-VL (better vision)
- Qwen4 series (2026)

### Evaluation Criteria
- Benchmark performance (HumanEval, MMLU, etc.)
- Memory efficiency
- Inference speed on Thor
- Quality vs current models

## Alternative Models

If you need different models:

### Code
- DeepSeek-Coder-33B
- CodeLlama-34B
- StarCoder2-15B

### Chat
- Llama-3.1-70B (requires 2 GPUs)
- Mistral-Large-2
- Yi-34B

### Vision
- LLaVA-1.6-34B
- Phi-3-Vision

See [deployment guide](03-deployment-guide.md) for model replacement instructions.
