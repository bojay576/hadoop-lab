#!/bin/bash
# =============================================================
# Hadoop Lab - Deploy on any Kubernetes cluster
# Usage: ./deploy.sh
# Prerequisites: kubectl with a running K8s/K3s cluster
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Prerequisites check
if ! command -v kubectl &>/dev/null; then
    error "kubectl not found. Please install kubectl first."
fi

if ! kubectl cluster-info &>/dev/null; then
    error "Cannot connect to cluster. Please check your KUBECONFIG."
fi

info "=== Step 1: Deploy K8s resources ==="
info "Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

info "Deploying ConfigMap..."
kubectl apply -f "$K8S_DIR/configmap.yaml"

info "Deploying HDFS NameNode..."
kubectl apply -f "$K8S_DIR/hdfs-namenode.yaml"

info "Waiting for NameNode to be ready..."
kubectl -n hadoop-lab rollout status statefulset/hdfs-namenode --timeout=180s

info "Deploying HDFS DataNode..."
kubectl apply -f "$K8S_DIR/hdfs-datanode.yaml"

info "Deploying YARN ResourceManager..."
kubectl apply -f "$K8S_DIR/yarn-resourcemanager.yaml"

info "Waiting for ResourceManager to be ready..."
kubectl -n hadoop-lab rollout status deployment/yarn-resourcemanager --timeout=180s

info "Deploying YARN NodeManager..."
kubectl apply -f "$K8S_DIR/yarn-nodemanager.yaml"

info "=== Step 2: Wait for all pods ==="
info "Waiting for all components to start..."
sleep 15

info "Current Pod status:"
kubectl -n hadoop-lab get pods -o wide

info "=== Step 3: Verify HDFS ==="
sleep 10

NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$NAMENODE_POD" ]; then
    info "NameNode Pod: $NAMENODE_POD"
    kubectl -n hadoop-lab exec "$NAMENODE_POD" -- hdfs dfsadmin -report 2>/dev/null || warn "HDFS report not ready yet."
fi

info "=== Deployment complete! ==="
echo ""
echo "========================================="
echo "  Hadoop Lab deployed successfully!"
echo "========================================="
echo ""
echo "  Access UIs (NodePort):"
echo "    HDFS NameNode:        http://<node-ip>:30870"
echo "    YARN ResourceManager: http://<node-ip>:30888"
echo ""
echo "  Experiments (run from project root):"
echo "    1 - HDFS basic ops:     ./experiments/01-hdfs-operations.sh"
echo "    2 - Generate test data: ./experiments/02-generate-data.py"
echo "    3 - WordCount MR job:   ./experiments/03-wordcount.sh"
echo "    4 - Custom MR analyzer: cd experiments/04-log-analyzer && ./build.sh"
echo "    5 - Full data pipeline: ./experiments/05-pipeline.sh"
echo ""
echo "  To clean up:"
echo "    ./cleanup.sh"
echo ""
echo "========================================="
