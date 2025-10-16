# FamilyAI Architecture

## System Overview

FamilyAI is a containerized AI service platform running on NVIDIA Jetson Thor, providing multiple AI capabilities through a unified gateway.

## Architecture Layers

### 1. Access Layer
- **Web UI** (Open WebUI) - Browser-based interface
- **API Gateway** - OpenAI-compatible REST API
- **IDE Integration** - VS Code, Cursor via Continue extension
- **Direct API** - curl, Python clients, etc.

### 2. Routing Layer
**Intelligent Gateway** (`gateway/router.py`)
- Task type detection (code vs chat vs vision)
- Context length analysis
- Model selection based on requirements
- Load balancing and request queuing
- Rate limiting and authentication

### 3. Service Layer
**vLLM Inference Services**
- Code Traditional: Qwen2.5-Coder-32B (traditional code tasks)
- Code Agentic: Qwen3-Coder-30B-A3B (agentic workflows, long context)
- Chat Advanced: Qwen3-32B (complex reasoning)
- Chat Fast: Qwen3-8B (balanced performance)
- Chat Light: Qwen3-4B (quick responses)
- Vision: Qwen2-VL-7B (image understanding)

**Speech Services**
- Whisper: Speech-to-text (ASR)
- Piper: Text-to-speech (TTS)

### 4. Inference Layer
**vLLM Engine**
- PagedAttention for memory efficiency
- Continuous batching for throughput
- INT4/AWQ quantization
- KV cache management
- Multi-GPU support (tensor parallelism)

### 5. Hardware Layer
**NVIDIA Jetson Thor**
- 128GB LPDDR5X unified memory
- 2070 TFLOPs (FP4) GPU compute
- Blackwell architecture with native FP4
- NVMe SSD for model storage

## Data Flow

```
User Request
    ↓
Gateway (task analysis)
    ↓
Model Selection Algorithm
    ↓
vLLM Service (inference)
    ↓
Response Streaming
    ↓
User
```

## Key Design Decisions

### 1. Unified vLLM Backend
**Why**: Consistency, shared optimizations, OpenAI API compatibility

### 2. Intelligent Routing
**Why**: Optimize resource usage, balance speed vs quality

### 3. Containerization
**Why**: Isolation, reproducibility, easy updates

### 4. Shared Model Cache
**Why**: Reduce storage, faster startup, easier management

### 5. INT4 Quantization
**Why**: 4x memory reduction, ~2x throughput, minimal quality loss

## Scalability

### Vertical Scaling
- Increase GPU count (tensor parallelism)
- Add more memory for larger batches
- Faster NVMe for model loading

### Horizontal Scaling
- Multiple Jetson Thor nodes
- K3s cluster for orchestration
- Shared model storage (NFS/Ceph)

## Security

### Network Isolation
- Services communicate via internal Docker network
- Only gateway exposed externally
- Optional HTTPS with certificates

### Authentication
- API key authentication (optional)
- Rate limiting per user/IP
- No telemetry or external data transfer

## Monitoring

### Metrics Collection
- Prometheus scrapes all services
- vLLM exposes inference metrics
- Gateway exposes routing decisions
- System metrics (GPU, memory, temperature)

### Visualization
- Grafana dashboards
- Real-time service health
- Historical performance trends

### Alerting
- High memory usage
- Service down
- High error rate
- GPU temperature

## Deployment Modes

### Development (Docker Compose)
- Single node deployment
- Quick iteration
- Manual service control

### Production (K3s)
- Auto-restart on failure
- Rolling updates
- Resource limits and requests
- Health checks and probes

See also:
- [Model Selection](02-model-selection.md)
- [Deployment Guide](03-deployment-guide.md)
