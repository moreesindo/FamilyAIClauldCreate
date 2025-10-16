#!/bin/bash
# FamilyAI K3s Deployment Script
# Deploys FamilyAI services to K3s Kubernetes cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}FamilyAI K3s Deployment${NC}"
echo "============================================"

# Check if K3s is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    echo "Please install K3s first:"
    echo "  curl -sfL https://get.k3s.io | sh -"
    exit 1
fi

# Check if K3s is running
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to K3s cluster${NC}"
    echo "Make sure K3s is running and you have proper permissions"
    exit 1
fi

echo -e "${GREEN}✅ K3s cluster is accessible${NC}"

# Load environment
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Creating from .env.example..."
    cp .env.example .env
fi

source .env

# Create namespace
NAMESPACE=${K3S_NAMESPACE:-familyai}
echo ""
echo "Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Check if K3s manifests exist
if [ ! -d k3s ]; then
    echo -e "${RED}Error: k3s directory not found${NC}"
    exit 1
fi

if [ -z "$(ls -A k3s/*.yaml 2>/dev/null)" ]; then
    echo -e "${RED}Error: No K3s manifests found in k3s/ directory${NC}"
    echo "Please create K3s deployment manifests first"
    exit 1
fi

# Apply manifests
echo ""
echo "Deploying services..."
for manifest in k3s/*.yaml; do
    echo "  Applying $(basename $manifest)..."
    kubectl apply -f $manifest -n $NAMESPACE
done

echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n $NAMESPACE || true

# Show deployment status
echo ""
echo -e "${GREEN}Deployment Status:${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${GREEN}Services:${NC}"
kubectl get svc -n $NAMESPACE

echo ""
echo -e "${GREEN}✅ K3s deployment complete!${NC}"
echo ""
echo "Useful commands:"
echo "  View pods: kubectl get pods -n $NAMESPACE"
echo "  View logs: kubectl logs -f <pod-name> -n $NAMESPACE"
echo "  Scale deployment: kubectl scale deployment <name> --replicas=N -n $NAMESPACE"
echo "  Delete deployment: kubectl delete namespace $NAMESPACE"
