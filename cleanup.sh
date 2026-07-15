#!/bin/bash
# =============================================================
# Hadoop Lab - 一键清理脚本
# 用法: ./cleanup.sh
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

read -p "确定要删除 Hadoop Lab 所有资源吗? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消."
    exit 0
fi

info "删除 YARN NodeManager..."
kubectl delete -f "$K8S_DIR/yarn-nodemanager.yaml" --ignore-not-found

info "删除 YARN ResourceManager..."
kubectl delete -f "$K8S_DIR/yarn-resourcemanager.yaml" --ignore-not-found

info "删除 HDFS DataNode..."
kubectl delete -f "$K8S_DIR/hdfs-datanode.yaml" --ignore-not-found

info "删除 HDFS NameNode..."
kubectl delete -f "$K8S_DIR/hdfs-namenode.yaml" --ignore-not-found

info "删除 ConfigMap..."
kubectl delete -f "$K8S_DIR/configmap.yaml" --ignore-not-found

info "删除命名空间..."
kubectl delete -f "$K8S_DIR/namespace.yaml" --ignore-not-found

info "清理节点上的数据目录..."
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@123.57.146.116 "
    for node in k3s-master k3s-worker-1 k3s-worker-2; do
        echo \"Cleaning \$node...\"
        ssh -o StrictHostKeyChecking=no \$node 'rm -rf /data/hadoop-lab' 2>/dev/null || true
    done
" 2>/dev/null || warn "无法清理节点数据，请手动清理."

info "=== 清理完成 ==="
