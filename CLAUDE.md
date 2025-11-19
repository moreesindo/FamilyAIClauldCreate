# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FamilyAI** is a family-oriented AI service center deployed on NVIDIA Jetson Thor, providing **5 core AI services**: code assistance (specialist), general AI assistance, vision understanding, speech recognition, and speech synthesis for family members.

**Design Philosophy**: Simplified, stable, and production-ready. Focus on core functionality with proven technologies. Dual LLM approach for specialized vs. general tasks.

---

## Core Development Principles

### Primary Requirement: Containerized Deployment on Jetson Thor

**ALL applications in this repository MUST be containerized and deployable on NVIDIA Jetson Thor servers.**

- All applications must run in Docker containers
- All applications must be compatible with NVIDIA Jetson Thor hardware (ARM64 architecture)
- Containerization is mandatory for every service
- Use `jetson-containers` or official llama.cpp images for optimal performance

### Hardware Specifications

**NVIDIA Jetson Thor**:
- Memory: 128GB LPDDR5X
- GPU Compute: 2070 TFLOPs FP4, 1035 TFLOPs FP8
- CUDA Cores: 2560 + 96 Tensor Cores
- Architecture: Blackwell with native FP4 support

### Development Workflow Rules

**IMPORTANT**: This project follows a strict development and deployment separation:

1. **Local Development Machine (开发机)**:
   - Used ONLY for code creation, modification, and version control
   - DO NOT run inference services locally
   - DO NOT execute model-related commands locally

2. **Jetson Thor Server (服务器端)**:
   - All code execution, testing, and debugging happens here
   - All model inference runs here
   - All Docker containers run here

3. **Claude Code's Role**:
   - Perform code edits and Git operations on local machine
   - Provide execution steps for server-side deployment
   - NEVER execute code running commands locally

---

## Architecture

### Technology Stack

```yaml
Inference Framework: llama.cpp (unified for LLM and multimodal)
Container Images:
  - ghcr.io/ggerganov/llama.cpp:server (for LLMs)
  - dustynv/llama.cpp:latest (for vision with llava support)
Quantization: Q4_K_M GGUF format (optimal quality/size balance)
Container Runtime: Docker with NVIDIA Container Toolkit
Orchestration: docker-compose (development) / K3s (production)
API Standard: OpenAI-compatible API
Frontend: Open WebUI (optional)
Monitoring: Prometheus + Grafana (optional)
Model Format: Pre-quantized GGUF from HuggingFace
```

### Service Architecture

```
┌─────────────────────────────────────────────┐
│         Family Member Access Layer          │
│   (Web UI / Mobile / VS Code / API)         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│       Optional: Routing Gateway             │
│    (Intelligent routing - 5 services)       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│         Docker Compose / K3s                │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           5 Core Service Containers         │
│                                             │
│  ┌──────────────┐  ┌──────────────────┐    │
│  │ Code Coder   │  │ AI Assistant     │    │
│  │ Qwen3-Coder  │  │ Qwen3-General    │    │
│  │ ~18.6GB      │  │ ~18.6GB          │    │
│  │ Port: 8001   │  │ Port: 8002       │    │
│  └──────────────┘  └──────────────────┘    │
│                                             │
│  ┌──────────────┐  ┌──────────────────┐    │
│  │ Vision       │  │ Whisper ASR      │    │
│  │ LLaVA 1.5    │  │ faster-whisper   │    │
│  │ ~4.9GB       │  │ ~2GB             │    │
│  │ Port: 8003   │  │ Port: 8004       │    │
│  └──────────────┘  └──────────────────┘    │
│                                             │
│  ┌──────────────┐                          │
│  │ Piper TTS    │                          │
│  │ Piper        │                          │
│  │ ~0.5GB       │                          │
│  │ Port: 8005   │                          │
│  └──────────────┘                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        llama.cpp Inference Engine           │
│    (Q4_K_M GGUF, efficient CPU/GPU usage)   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           Jetson Thor Hardware              │
│       (128GB RAM, 2070 FP4 TFLOPS)          │
│     Total Memory Usage: ~44.6GB / 128GB     │
│     Remaining: ~83.4GB for concurrency      │
└─────────────────────────────────────────────┘
```

---

## Core Services

### Service 1: Code Specialist (Qwen3-Coder-30B-A3B MoE)

**Model**: `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF`
**Quantization**: Q4_K_M
**Parameters**: 30B total, 3.3B active (MoE architecture)
**Memory**: ~18.6GB
**Port**: 8001
**Context**: 32K tokens

**Use Cases**:
- **Code generation and completion** (PRIMARY)
- Code refactoring and optimization
- Bug fixing and debugging
- Algorithm implementation
- Code review and analysis
- Technical documentation generation

**Performance** (Jetson Thor estimate):
- Prefill: 40-60 tokens/sec
- Generation: 70-90 tokens/sec
- Concurrent users: 5-8
- **HumanEval/MBPP**: Industry-leading scores

**Why this model**:
- **Specialized for code**: Trained specifically on code datasets
- MoE architecture: Only 3.3B params active per request
- Superior performance on coding benchmarks
- Pre-quantized GGUF available (no conversion needed)
- Proven stability with llama.cpp

**When to use**: All code-related tasks, IDE integration, VS Code Continue plugin

---

### Service 2: AI Assistant (Qwen3-30B-A3B MoE)

**Model**: `unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF`
**Quantization**: Q4_K_M
**Parameters**: 30B total, 3.3B active (MoE architecture)
**Memory**: ~18.6GB
**Port**: 8002
**Context**: 32K tokens

**Use Cases**:
- **General conversation and dialogue** (PRIMARY)
- Creative writing and content generation
- Multi-domain reasoning
- Task planning and brainstorming
- Document analysis and summarization
- Mixed-task workflows (audio/video processing guidance)

**Performance** (Jetson Thor estimate):
- Prefill: 40-60 tokens/sec
- Generation: 70-90 tokens/sec
- Concurrent users: 5-8

**Why this model**:
- **Broad knowledge base**: General-purpose training
- MoE architecture: Efficient resource usage
- Native 256K context, extended to 1M with YaRN
- Excellent multi-task capabilities
- Pre-quantized GGUF available

**When to use**: Non-code tasks, creative work, general assistance, audio/video workflow planning

---

### Service 3: Vision Understanding (LLaVA 1.5-7B)

**Model**: `mys/ggml_llava-v1.5-7b`
**Quantization**: Q4_K_M (language model) + FP16 (mmproj)
**Parameters**: 7B
**Memory**: ~4.9GB (4.1GB model + 0.6GB mmproj + 0.2GB compute)
**Port**: 8003
**Context**: 16K tokens

**Use Cases**:
- Image understanding and description
- Visual question answering
- Object recognition
- Scene understanding
- Basic OCR
- Photo analysis

**Performance** (Jetson Thor estimate):
- Image processing: 10-20 seconds
- Text generation: 80-120 tokens/sec
- Concurrent users: 5-8

**Why this model**:
- Official Jetson AI Lab support (proven on Thor)
- Excellent llama.cpp integration via `llama-mtmd-cli`
- Stable mmproj format
- Good balance of capability and resource usage
- Pre-quantized GGUF available

**Note**: For OCR-heavy workloads, Qwen2-VL-7B can be substituted (requires fork setup).

### Service 4: Speech Recognition (Whisper ASR)

**Model**: `Systran/faster-whisper-small`
**Format**: CTranslate2
**Parameters**: 244M
**Memory**: ~2GB
**Port**: 8004

**Use Cases**:
- Audio transcription to text
- Video audio extraction and transcription
- Real-time speech recognition
- Multi-language support (auto-detect)

**Performance** (Jetson Thor estimate):
- Real-time factor: <0.3 (faster than real-time)
- Concurrent users: 10+

### Service 5: Speech Synthesis (Piper TTS)

**Model**: `en_US-lessac-medium`
**Format**: Piper native
**Parameters**: <100M
**Memory**: ~0.5GB
**Port**: 8005

**Use Cases**:
- Text-to-speech conversion
- Podcast voice generation
- Audio book narration
- Voice assistance

**Performance** (Jetson Thor estimate):
- Real-time synthesis
- Concurrent users: 12-15

---

## Resource Allocation

### Memory Budget (Total: 128GB)

| Service | Memory | Port | Status | Purpose |
|---------|--------|------|--------|---------|
| **Code Coder** | ~18.6GB | 8001 | Core | Code-only tasks |
| **AI Assistant** | ~18.6GB | 8002 | Core | General assistant |
| **Vision (LLaVA)** | ~4.9GB | 8003 | Core | Image understanding |
| **Whisper ASR** | ~2GB | 8004 | Core | Speech-to-text |
| **Piper TTS** | ~0.5GB | 8005 | Core | Text-to-speech |
| **Total Used** | **~44.6GB** | - | - | - |
| **Remaining** | **~83.4GB** | - | - | Concurrency/batching |

**Note**: Two 30B models can run simultaneously on Thor's 128GB RAM without issue.

### Performance Expectations (Jetson Thor)

| Model | Tokens/sec | Concurrent Users | Response Time |
|-------|-----------|------------------|---------------|
| Qwen3-Coder (Code) | 70-90 | 5-8 | 1-3s |
| Qwen3-General (AI) | 70-90 | 5-8 | 1-3s |
| LLaVA-1.5-7B (Vision) | 80-120 | 5-8 | 2-4s (+ image) |
| Whisper-Small (ASR) | 10x RT | 10+ | <0.5s |
| Piper (TTS) | RT | 12-15 | <0.2s |

---

## Development Workflow

### Getting Started

1. **Clone and Setup**:
```bash
# On local development machine
git clone <repository>
cd FamilyAI
cp .env.example .env
nano .env  # Edit configuration for your server
```

2. **Download GGUF Models** (on Jetson Thor server):
```bash
# SSH into Jetson Thor
ssh sindoyang@<jetson-thor-ip>
cd /path/to/FamilyAI

# Download all GGUF models (automatic, uses HuggingFace)
./scripts/download-gguf-models.sh

# Or download specific models
./scripts/download-gguf-models.sh --model code-coder
./scripts/download-gguf-models.sh --model ai-assistant
./scripts/download-gguf-models.sh --model vision-llava
```

**Downloaded files**:
- `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf` (~18.6GB) - Code specialist
- `Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf` (~18.6GB) - General AI
- `ggml-model-q4_k.gguf` (LLaVA language model, ~4.1GB)
- `mmproj-model-f16.gguf` (LLaVA vision projector, ~0.6GB)
- **Total**: ~41.9GB

3. **Deploy Services** (on Jetson Thor server):

**Option A: Core Services Only (Recommended for initial deployment)**
```bash
# Start 5 core services
docker-compose up -d code-coder ai-assistant vision whisper piper
```

**Option B: Full Stack (with gateway and web UI)**
```bash
# Start all services including gateway and web UI
docker-compose --profile full up -d
```

**Option C: With Monitoring**
```bash
# Start with Prometheus + Grafana monitoring
docker-compose --profile full --profile monitoring up -d
```

4. **Health Check** (on Jetson Thor server):
```bash
# Check all services are running
docker-compose ps

# Check service health
curl http://localhost:8001/health  # Code Coder
curl http://localhost:8002/health  # AI Assistant
curl http://localhost:8003/health  # Vision
curl http://localhost:8004/health  # Whisper
curl http://localhost:8005/health  # Piper
```

5. **Test Inference** (on Jetson Thor server):

**Code Assistant**:
```bash
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-30b-a3b",
    "messages": [{"role": "user", "content": "Write a Python function to calculate factorial"}],
    "max_tokens": 512
  }'
```

**Vision (LLaVA)**:
```bash
# Note: Vision API requires image input - use appropriate client
# Example with llama-mtmd-cli in container:
docker exec -it familyai-vision llama-mtmd-cli \
  --model /models/ggml-model-q4_k.gguf \
  --mmproj /models/mmproj-model-f16.gguf \
  --image /path/to/image.jpg \
  --prompt "Describe this image"
```

### Adding New Features

1. Create feature branch on local machine
2. Make code changes locally
3. Commit and push to repository
4. Pull changes on Jetson Thor server
5. Test on Jetson Thor server
6. Verify functionality
7. Merge to main branch after validation

### Model Management

**Updating Models**:
1. Update `.env` file with new model name
2. Run download script: `./scripts/download-gguf-models.sh --model <model-name>`
3. Restart affected service: `docker-compose restart <service>`

**Model Storage**:
- GGUF models: `/home/sindoyang/.cache/familyai/gguf`
- HuggingFace cache: `/home/sindoyang/.cache/huggingface`
- Whisper models: Downloaded automatically on first run
- Piper models: Stored in Docker volume `piper-models`

---

## Deployment Commands

### Development Deployment (docker-compose)

**Start Core Services**:
```bash
docker-compose up -d code-agentic vision whisper piper
```

**Start with Gateway**:
```bash
docker-compose --profile full up -d
```

**View Logs**:
```bash
docker-compose logs -f code-agentic
docker-compose logs -f vision
docker-compose logs -f whisper
docker-compose logs -f piper
```

**Stop Services**:
```bash
docker-compose down
```

**Restart Single Service**:
```bash
docker-compose restart code-agentic
```

### Production Deployment (K3s)

**Prerequisites**:
```bash
# Install K3s on Jetson Thor
curl -sfL https://get.k3s.io | sh -
```

**Deploy**:
```bash
# Apply manifests (create if needed)
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/configmap.yaml
kubectl apply -f k3s/deployments/
kubectl apply -f k3s/services/
```

**Monitor**:
```bash
kubectl get pods -n familyai
kubectl logs -f -n familyai deployment/code-agentic
```

---

## API Access

### OpenAI-Compatible API

All services expose OpenAI-compatible endpoints:

**Code Assistant (Port 8001)**:
```bash
curl http://<jetson-thor-ip>:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-code",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

**Via Gateway (Port 8080, if enabled)**:
```bash
curl http://<jetson-thor-ip>:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

### VS Code Integration

Install **Continue** extension and configure:

```json
{
  "models": [
    {
      "title": "FamilyAI Code",
      "provider": "openai",
      "model": "qwen3-code",
      "apiBase": "http://<jetson-thor-ip>:8001/v1"
    }
  ]
}
```

### Web UI Access

If deployed with `--profile full`:
- Open WebUI: `http://<jetson-thor-ip>:3000`
- Default login: Create account on first visit
- Configure models in settings to use gateway endpoint

---

## Monitoring and Operations

### Health Checks

All services expose `/health` endpoint:
```bash
curl http://localhost:8001/health  # Code Assistant
curl http://localhost:8002/health  # Vision
curl http://localhost:8003/health  # Whisper ASR
curl http://localhost:8004/health  # Piper TTS
curl http://localhost:8080/health  # Gateway (if enabled)
```

### Metrics

If Prometheus enabled (`--profile monitoring`):
- Prometheus: `http://<jetson-thor-ip>:9090`
- Grafana: `http://<jetson-thor-ip>:3001` (admin/admin)

Metrics endpoints:
- llama.cpp services: `http://localhost:800X/metrics`
- Gateway: `http://localhost:8080/metrics`

### Logs

**View service logs**:
```bash
docker-compose logs -f <service-name>
docker-compose logs --tail=100 code-agentic
```

**Log files**: Stored in JSON format, max 10MB per file, 3 files retained

### Resource Monitoring

```bash
# Check container resource usage
docker stats

# Check GPU usage
nvidia-smi

# Check system memory
free -h
```

---

## Troubleshooting

### Common Issues

**Out of Memory (OOM)**:
- Check: `docker stats` and `nvidia-smi`
- Solution: Reduce `LLAMACPP_N_PARALLEL` in `.env`
- Solution: Use smaller context size (`CODE_AGENTIC_MAX_MODEL_LEN`)

**Slow Inference**:
- Check: GPU utilization with `nvidia-smi`
- Verify: `LLAMACPP_GPU_LAYERS=999` (all layers on GPU)
- Check: Thermal throttling with `nvidia-smi`

**Model Download Fails**:
- Verify: Internet connectivity and proxy settings
- Check: `PROXY_URL` in `.env`
- Try: Manual download and place in `$GGUF_OUTPUT_DIR`

**Service Won't Start**:
- Check: GGUF files exist in `$GGUF_OUTPUT_DIR`
- Verify: File permissions (readable by Docker)
- Check logs: `docker-compose logs <service>`

**Vision Service Issues**:
- Verify: Both `ggml-model-q4_k.gguf` AND `mmproj-model-f16.gguf` exist
- Check: Using correct image `dustynv/llama.cpp:latest`
- Verify: Command uses `llama-mtmd-cli` (not standard llama-server)

### Performance Tuning

**Increase Throughput**:
- Increase `LLAMACPP_N_PARALLEL` (uses more memory)
- Reduce context size if not needed
- Use batch processing for multiple requests

**Reduce Latency**:
- Ensure `LLAMACPP_GPU_LAYERS=999`
- Reduce `LLAMACPP_N_PARALLEL`
- Use smaller models if acceptable

**Memory Optimization**:
- Reduce parallel requests
- Reduce context sizes
- Consider Q3_K_M quantization (lower quality, smaller size)

---

## Testing

### Unit Tests

```bash
# On Jetson Thor server
pytest tests/test_services.py
pytest tests/test_llama_cpp.py
```

### Integration Tests

```bash
# Test full workflow
./scripts/test-integration.sh
```

### Performance Benchmarks

```bash
# Benchmark inference speed
./scripts/benchmark-performance.sh

# Code model benchmark (HumanEval, MBPP)
./scripts/benchmark-code.sh
```

---

## Security Considerations

### Network Access

- Services bind to `0.0.0.0` inside containers
- Exposed ports: 8001-8004 (core), 8080 (gateway), 3000 (webui)
- For external access: Use reverse proxy (Traefik/Nginx) with HTTPS
- Implement rate limiting per IP/user

### Authentication

- API authentication disabled by default (home use)
- Enable in `.env`: `API_AUTH_ENABLED=true`
- Set secure key: `API_KEY=<random-secure-key>`
- Web UI: Requires account creation (controlled by `WEBUI_ENABLE_SIGNUP`)

### Data Privacy

- **All processing is local** on Jetson Thor
- No external API calls
- No telemetry or usage data sent externally
- Conversation history stored locally (opt-in in Web UI)

---

## Project Structure Reference

```
FamilyAI/
├── CLAUDE.md                       # This file
├── README.md                       # User documentation
├── .env.example                    # Environment template
├── docker-compose.yml              # Service definitions (4 core + optional)
├── scripts/
│   ├── download-gguf-models.sh     # Download pre-quantized GGUF models
│   ├── test-integration.sh         # Integration tests
│   └── benchmark-performance.sh    # Performance benchmarks
├── whisper/                        # Whisper ASR service
│   ├── Dockerfile
│   └── config.yaml
├── piper/                          # Piper TTS service
│   ├── Dockerfile
│   └── config.yaml
├── gateway/                        # Optional routing gateway
│   ├── Dockerfile
│   ├── router.py
│   └── config.yaml
├── k3s/                            # Production K3s manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployments/
│   └── services/
├── monitoring/                     # Prometheus + Grafana configs
│   ├── prometheus.yml
│   ├── alerts.yaml
│   └── grafana-dashboard.json
├── tests/                          # Test suites
│   ├── test_services.py
│   └── test_llama_cpp.py
└── docs/                           # Additional documentation
    ├── DEPLOYMENT.md
    ├── API.md
    └── TROUBLESHOOTING.md
```

---

## Migration Notes

### From Previous vLLM-based Architecture

This version has been **simplified from a complex multi-model vLLM architecture** to a **stable 4-service llama.cpp architecture**:

**Changes**:
- ❌ Removed: vLLM inference engine (compatibility issues on Jetson Thor)
- ❌ Removed: 5 LLM models (code-traditional, chat-advanced, chat-fast, chat-light)
- ✅ Added: llama.cpp as unified inference engine (proven stability)
- ✅ Simplified: 1 code model (Qwen3-30B-A3B MoE - covers all code tasks)
- ✅ Simplified: 1 vision model (LLaVA 1.5-7B - stable and supported)
- ✅ Retained: Whisper ASR and Piper TTS (unchanged)

**Benefits**:
- Reduced complexity: 4 services vs 8 services
- Reduced memory: ~26GB vs ~48GB
- Improved stability: llama.cpp proven on Jetson platforms
- Easier maintenance: Fewer moving parts
- Better performance: MoE model provides excellent code capability in smaller footprint

**Migration Path**:
1. Stop old vLLM services: `docker-compose down`
2. Download GGUF models: `./scripts/download-gguf-models.sh`
3. Start new services: `docker-compose up -d`
4. Test functionality with new endpoints
5. Update client integrations (VS Code, API clients)

---

## Support and References

### Official Documentation

- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **Jetson AI Lab - LLaVA**: https://www.jetson-ai-lab.com/tutorial_llava.html
- **Jetson Containers**: https://github.com/dusty-nv/jetson-containers

### Model Cards

- **Qwen3-30B-A3B**: https://huggingface.co/Qwen/Qwen3-30B-A3B-Instruct-2507
- **Qwen3 GGUF**: https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF
- **LLaVA GGUF**: https://huggingface.co/mys/ggml_llava-v1.5-7b
- **Whisper**: https://github.com/SYSTRAN/faster-whisper
- **Piper TTS**: https://github.com/rhasspy/piper

### Community Resources

- **Jetson Forums**: https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems
- **llama.cpp Discussions**: https://github.com/ggerganov/llama.cpp/discussions

---

**Last Updated**: 2025-01-16
**Jetson Thor Platform**: Production Ready
**Architecture**: Simplified llama.cpp Edition
**Primary Models**: Qwen3-30B-A3B (Code) + LLaVA-1.5-7B (Vision)
**Status**: ✅ Stable, ✅ Tested, ✅ Recommended for Production
