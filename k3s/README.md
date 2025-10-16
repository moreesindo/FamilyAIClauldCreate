# FamilyAI K3s Deployment Manifests

This directory contains Kubernetes manifests for deploying FamilyAI on K3s.

## Files

- `00-namespace.yaml` - FamilyAI namespace
- `01-configmap.yaml` - Configuration and environment variables
- `02-persistent-volume.yaml` - Storage for model cache
- `10-gateway-deployment.yaml` - API gateway deployment and service
- `20-chat-fast-deployment.yaml` - Example vLLM service deployment

## Deployment Order

The manifests are numbered to indicate deployment order:
1. Namespace (00)
2. ConfigMaps and PVCs (01-02)
3. Core services (10-19)
4. vLLM services (20-29)
5. Additional services (30+)

## Usage

### Deploy All Services

```bash
./scripts/04-deploy-k3s.sh
```

### Deploy Individual Service

```bash
kubectl apply -f k3s/20-chat-fast-deployment.yaml -n familyai
```

### Check Status

```bash
kubectl get pods -n familyai
kubectl logs -f <pod-name> -n familyai
```

## Creating Additional Service Manifests

Use `20-chat-fast-deployment.yaml` as a template for other vLLM services:

1. Copy the file
2. Replace service name (chat-fast → your-service)
3. Update MODEL configMap reference
4. Adjust resource limits
5. Update max-model-len if needed

## Resource Requirements

Each vLLM service requires:
- **GPU**: 1 NVIDIA GPU
- **Memory**:
  - 32B models: ~24GB
  - 8B models: ~8GB
  - 4B models: ~4GB
  - 7B vision: ~6GB

Ensure your Jetson Thor has sufficient resources.

## Storage

Models are stored in a shared PVC mounted at `/data/huggingface`. This allows:
- Shared model cache across pods
- Persistent storage across deployments
- Pre-downloaded models for faster startup

## Networking

Services are exposed internally via ClusterIP. External access is through:
- Gateway (LoadBalancer) on port 8080
- Direct service access if needed

## Configuration

Edit `01-configmap.yaml` to adjust:
- Proxy settings
- vLLM parameters
- Model names
- Resource limits

## Monitoring

For production deployments, also deploy:
- Prometheus (for metrics collection)
- Grafana (for visualization)
- AlertManager (for alerts)

See `monitoring/` directory for configurations.
