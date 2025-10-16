# Troubleshooting Guide

## Common Issues

### 1. Services Won't Start

#### Symptom
```bash
docker-compose up -d
# Container exits immediately
```

#### Diagnosis
```bash
docker-compose logs code-traditional
```

#### Solutions

**NVIDIA Runtime Not Found**
```bash
# Install nvidia-container-toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

**Model Not Found**
```bash
# Download model
./scripts/02-pull-models.sh --model code-traditional

# Check cache
ls ~/.cache/huggingface/hub/
```

**Out of Memory**
```bash
# Check available memory
free -h

# Reduce GPU memory utilization in .env
VLLM_GPU_MEMORY_UTILIZATION=0.85
```

### 2. Proxy Issues

#### Symptom
Model download fails with connection timeout

#### Diagnosis
```bash
# Test proxy from host
curl -x http://127.0.0.1:2526 https://huggingface.co

# Test from container
docker run --rm --network host -e HTTP_PROXY=http://host-ip:2526 curlimages/curl \
  -x http://host-ip:2526 https://huggingface.co
```

#### Solutions
```bash
# Run proxy configuration wizard
./scripts/configure-proxy.sh

# Ensure proxy listens on 0.0.0.0, not 127.0.0.1
# Edit Clash config:
bind-address: 0.0.0.0

# Restart proxy service
```

### 3. High GPU Temperature

#### Symptom
- GPU temp > 80°C
- Thermal throttling
- Reduced performance

#### Solutions
```bash
# Check current temperature
nvidia-smi

# Improve cooling
- Clean dust from fans
- Ensure proper airflow
- Add external fan

# Reduce load
- Lower GPU utilization
- Reduce batch size
- Disable some services
```

### 4. Slow Inference

#### Symptom
Requests take >10 seconds for simple queries

#### Diagnosis
```bash
# Check GPU utilization
nvidia-smi

# Check container resources
docker stats

# Run benchmark
./scripts/06-benchmark.sh
```

#### Solutions

**Low GPU Utilization**
```bash
# Increase batch size
VLLM_MAX_NUM_SEQS=256

# Enable CUDA graphs
VLLM_ENABLE_CUDA_GRAPH=true
```

**High Queue Length**
```bash
# Check vLLM logs
docker-compose logs chat-fast

# Add more instances (if memory allows)
docker-compose up -d --scale chat-fast=2

# Or route to lighter model
# Gateway automatically does this
```

**Swap Thrashing**
```bash
# Check swap usage
free -h

# Disable swap for Docker
sudo systemctl edit docker
# Add:
[Service]
LimitMEMLOCK=infinity

# Or reduce services
```

### 5. Gateway Routing Issues

#### Symptom
Requests routed to wrong model

#### Diagnosis
```bash
# Check gateway logs
docker-compose logs gateway

# Test specific model
curl http://localhost:8080/v1/chat/completions \
  -d '{"model": "chat-fast", "messages": [...]}'
```

#### Solutions
```bash
# Adjust routing thresholds in .env
GATEWAY_CODE_CONTEXT_THRESHOLD=8192
GATEWAY_CHAT_SIMPLE_MAX_TOKENS=100

# Or specify model explicitly in requests
```

### 6. Docker Compose vs docker compose

#### Symptom
Command not found error

#### Solution
```bash
# Use Docker Compose V2 (built-in)
docker compose up -d

# Or install V1 separately
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## FAQ

### Q: How much storage do I need?
**A**: ~200GB total (150GB models + 50GB system/logs)

### Q: Can I use only some services?
**A**: Yes! Comment out unused services in `docker-compose.yml`

### Q: How do I update models?
**A**: Download new model, update `.env`, restart service

### Q: Services start but can't access?
**A**: Check firewall rules, verify ports not in use

### Q: Can I run on other GPUs?
**A**: Yes, but need 48GB+ VRAM. Works on A100, H100, or multi-GPU setups

### Q: How to enable HTTPS?
**A**: See [Deployment Guide](03-deployment-guide.md#security-hardening)

## Getting Help

### Check Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f gateway

# Last 100 lines
docker-compose logs --tail=100 code-traditional
```

### Health Check
```bash
./scripts/05-health-check.sh
```

### System Info
```bash
# GPU info
nvidia-smi

# Docker info
docker info

# Disk space
df -h

# Memory
free -h
```

### Report Issues

When reporting issues, include:
1. Error messages (full logs)
2. System info (nvidia-smi, docker info)
3. Configuration (.env, docker-compose.yml)
4. Steps to reproduce

GitHub Issues: https://github.com/yourusername/FamilyAI/issues

## Advanced Debugging

### Enable Debug Logging
```bash
# In .env
LOG_LEVEL=DEBUG
GATEWAY_LOG_LEVEL=DEBUG

# Restart services
docker-compose restart
```

### Profile vLLM
```bash
# Add to service environment
VLLM_TRACE_FUNCTION=1
VLLM_LOG_LEVEL=DEBUG
```

### Monitor in Real-time
```bash
# GPU usage
watch -n 1 nvidia-smi

# Container stats
watch -n 1 docker stats

# Network traffic
docker-compose exec gateway nethogs
```
