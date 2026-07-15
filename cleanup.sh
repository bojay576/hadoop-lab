#!/bin/bash
# =============================================================
# Hadoop Lab - Clean up from any Kubernetes cluster
# Usage: ./cleanup.sh
# Prerequisites: kubectl with access to the target cluster
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

read -p "Delete all Hadoop Lab resources in namespace 'hadoop-lab'? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

info "Deleting YARN NodeManager..."
kubectl delete -f "$K8S_DIR/yarn-nodemanager.yaml" --ignore-not-found

info "Deleting YARN ResourceManager..."
kubectl delete -f "$K8S_DIR/yarn-resourcemanager.yaml" --ignore-not-found

info "Deleting HDFS DataNode..."
kubectl delete -f "$K8S_DIR/hdfs-datanode.yaml" --ignore-not-found

info "Deleting HDFS NameNode..."
kubectl delete -f "$K8S_DIR/hdfs-namenode.yaml" --ignore-not-found

info "Deleting ConfigMap..."
kubectl delete -f "$K8S_DIR/configmap.yaml" --ignore-not-found

info "Deleting namespace..."
kubectl delete -f "$K8S_DIR/namespace.yaml" --ignore-not-found

info "=== Cleanup complete ==="
