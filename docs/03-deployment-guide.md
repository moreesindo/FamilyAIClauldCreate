# Deployment Guide

## Prerequisites

### Hardware
- NVIDIA Jetson Thor (128GB RAM)
- 256GB+ NVMe SSD storage
- Network connectivity
- Optional: UPS for power protection

### Software
- Ubuntu 22.04 (JetPack 6.0+)
- Docker 20.10+
- NVIDIA Container Toolkit
- (Optional) K3s for production

## Quick Start

See [README.md](../README.md#快速开始) for basic setup.

## Detailed Deployment Steps

### 1. System Preparation

```bash
# Run Jetson setup script
sudo ./scripts/00-jetson-setup.sh
```

This script:
- Installs Docker and NVIDIA runtime
- Configures system settings
- Sets up swap space
- Optimizes GPU settings

### 2. Proxy Configuration

```bash
./scripts/configure-proxy.sh
```

Follow the interactive wizard to:
- Detect host IP
- Find proxy services
- Configure .env file
- Test connectivity

### 3. Model Download

```bash
# Batch download (recommended)
./scripts/02-pull-models.sh --batch

# Individual models
./scripts/02-pull-models.sh --model chat-fast
```

**Storage Requirements**:
- Code Traditional: ~35GB
- Code Agentic: ~32GB
- Chat Advanced: ~35GB
- Chat Fast: ~9GB
- Chat Light: ~4.5GB
- Vision: ~8GB
- Whisper: ~1.5GB
- **Total**: ~125GB

### 4. Service Deployment

#### Docker Compose (Development)

```bash
# Basic deployment (no monitoring)
./scripts/03-deploy-docker-compose.sh

# Full deployment (with monitoring)
./scripts/03-deploy-docker-compose.sh full
```

#### K3s (Production)

```bash
# Deploy to K3s
./scripts/04-deploy-k3s.sh
```

### 5. Verification

```bash
# Check service health
./scripts/05-health-check.sh

# Run benchmarks
./scripts/06-benchmark.sh
```

## Configuration

### Environment Variables

Edit `.env` file for:
- Proxy settings
- Model paths
- Port mappings
- Resource limits
- API authentication

Key variables:
```bash
PROXY_URL=http://192.168.3.84:2526
HF_HOME=/home/user/.cache/huggingface
VLLM_GPU_MEMORY_UTILIZATION=0.9
GATEWAY_PORT=8080
```

### Resource Tuning

#### GPU Memory
```bash
# Aggressive (may OOM under load)
VLLM_GPU_MEMORY_UTILIZATION=0.95

# Conservative (safer)
VLLM_GPU_MEMORY_UTILIZATION=0.85
```

#### Batch Size
```bash
# Higher throughput, more memory
VLLM_MAX_NUM_SEQS=512

# Lower memory usage
VLLM_MAX_NUM_SEQS=128
```

## Troubleshooting

### Out of Memory

**Symptoms**: Container crashes, CUDA OOM errors

**Solutions**:
1. Reduce GPU memory utilization
2. Lower max sequence length
3. Disable some services
4. Use INT8 instead of INT4 (less efficient but more stable)

### Slow Inference

**Symptoms**: High latency, low throughput

**Diagnosis**:
```bash
# Check GPU utilization
nvidia-smi

# Check container stats
docker stats
```

**Solutions**:
1. Verify INT4 quantization is active
2. Check for thermal throttling
3. Reduce concurrent requests
4. Optimize model selection

### Model Loading Fails

**Symptoms**: Container won't start, model not found errors

**Solutions**:
1. Verify model download completed
2. Check HF_HOME path
3. Ensure sufficient disk space
4. Check proxy configuration

See [Troubleshooting Guide](05-troubleshooting.md) for more details.

## Updating

### Update Models
```bash
# Download new model version
MODEL_NAME=Qwen/Qwen3-35B-Instruct ./scripts/02-pull-models.sh

# Update docker-compose.yml or K3s manifests
# Restart services
```

### Update Services
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

## Backup and Recovery

### Backup
```bash
# Backup configuration
tar -czf familyai-config-$(date +%Y%m%d).tar.gz .env docker-compose.yml k3s/

# Backup data
tar -czf familyai-data-$(date +%Y%m%d).tar.gz data/
```

### Recovery
```bash
# Restore configuration
tar -xzf familyai-config-YYYYMMDD.tar.gz

# Restore data
tar -xzf familyai-data-YYYYMMDD.tar.gz

# Redeploy
./scripts/03-deploy-docker-compose.sh
```

## Security Hardening

### Enable Authentication
```bash
# In .env
API_AUTH_ENABLED=true
API_KEY=your-secure-random-key

# Restart gateway
docker-compose restart gateway
```

### HTTPS Setup
```bash
# Generate certificates
sudo certbot certonly --standalone -d familyai.yourdomain.com

# Update .env
ENABLE_HTTPS=true
SSL_CERT_PATH=/etc/letsencrypt/live/familyai.yourdomain.com/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/familyai.yourdomain.com/privkey.pem
```

### Firewall
```bash
# Allow only specific IPs
sudo ufw allow from 192.168.1.0/24 to any port 8080
sudo ufw enable
```

## Monitoring

### Access Dashboards
- Prometheus: http://jetson-ip:9090
- Grafana: http://jetson-ip:3001
  - Default credentials: admin/admin

### Key Metrics
- GPU utilization and temperature
- Memory usage per service
- Request latency (p50, p95, p99)
- Throughput (requests/sec, tokens/sec)

### Alerts
Configure in `monitoring/alerts.yaml`:
- High GPU temperature (>80°C)
- High memory usage (>90%)
- Service down (>5min)
- High error rate (>5%)

See [Architecture](01-architecture.md) for system design details.
