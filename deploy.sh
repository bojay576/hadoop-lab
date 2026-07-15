#!/bin/bash
# =============================================================
# Hadoop Lab - 一键部署脚本
# 用法: ./deploy.sh
# 前提: 已通过 SSH 连接到 k3s 主节点，或设置了 KUBECONFIG
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"
DOCKER_DIR="$SCRIPT_DIR/docker"
IMAGE_NAME="hadoop-lab"
IMAGE_TAG="latest"
IMAGE_FULL="$IMAGE_NAME:$IMAGE_TAG"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检测 kubectl
if ! command -v kubectl &>/dev/null; then
    error "kubectl not found. Please install kubectl first."
fi

info "=== Step 1: 构建 Docker 镜像 ==="
# 将 docker 目录和 entrypoint 复制到主节点进行构建
info "将 Dockerfile 和 entrypoint.sh 传输到主节点..."
sshpass -p 'root' scp -o StrictHostKeyChecking=no \
    "$DOCKER_DIR/Dockerfile" "$DOCKER_DIR/entrypoint.sh" \
    root@123.57.146.116:/tmp/

info "在主节点构建镜像..."
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@123.57.146.116 "
    cd /tmp
    # 使用 k3s 内置的 containerd (ctr) 或 docker
    if command -v docker &>/dev/null; then
        docker build -t $IMAGE_FULL -f Dockerfile .
    else
        # k3s 使用 containerd, 用 buildctl 或导入
        # 先在主节点检查是否有 docker
        echo 'Docker not found, checking for nerdctl...'
        if command -v nerdctl &>/dev/null; then
            nerdctl build -t $IMAGE_FULL -f Dockerfile .
        else
            echo 'Installing docker for build...'
            curl -fsSL https://get.docker.com | sh
            systemctl start docker
            docker build -t $IMAGE_FULL -f Dockerfile .
        fi
    fi
"

info "=== Step 2: 分发镜像到所有节点 ==="
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@123.57.146.116 "
    # 导出镜像
    if command -v docker &>/dev/null; then
        docker save $IMAGE_FULL -o /tmp/$IMAGE_NAME.tar
    elif command -v nerdctl &>/dev/null; then
        nerdctl save $IMAGE_FULL -o /tmp/$IMAGE_NAME.tar
    fi

    # 导入到 containerd (k3s 使用的容器运行时)
    ctr -n k8s.io images import /tmp/$IMAGE_NAME.tar 2>/dev/null || \
    k3s ctr images import /tmp/$IMAGE_NAME.tar 2>/dev/null || \
    echo 'Import via ctr failed, trying nerdctl...'

    # 传输到 worker 节点
    for worker in k3s-worker-1 k3s-worker-2; do
        echo \"Sending image to \$worker...\"
        scp -o StrictHostKeyChecking=no /tmp/$IMAGE_NAME.tar \$worker:/tmp/
        ssh -o StrictHostKeyChecking=no \$worker \"
            ctr -n k8s.io images import /tmp/$IMAGE_NAME.tar 2>/dev/null || \
            k3s ctr images import /tmp/$IMAGE_NAME.tar 2>/dev/null || \
            echo 'Import failed on \$worker'
            rm -f /tmp/$IMAGE_NAME.tar
        \"
    done

    rm -f /tmp/$IMAGE_NAME.tar
"

info "=== Step 3: 部署 K8s 资源 ==="
info "创建命名空间..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

info "部署 ConfigMap..."
kubectl apply -f "$K8S_DIR/configmap.yaml"

info "部署 HDFS NameNode..."
kubectl apply -f "$K8S_DIR/hdfs-namenode.yaml"

info "等待 NameNode 就绪..."
kubectl -n hadoop-lab rollout status statefulset/hdfs-namenode --timeout=180s

info "部署 HDFS DataNode..."
kubectl apply -f "$K8S_DIR/hdfs-datanode.yaml"

info "部署 YARN ResourceManager..."
kubectl apply -f "$K8S_DIR/yarn-resourcemanager.yaml"

info "等待 ResourceManager 就绪..."
kubectl -n hadoop-lab rollout status deployment/yarn-resourcemanager --timeout=180s

info "部署 YARN NodeManager..."
kubectl apply -f "$K8S_DIR/yarn-nodemanager.yaml"

info "=== Step 4: 等待所有 Pod 就绪 ==="
info "等待所有组件启动..."
sleep 15

info "当前 Pod 状态:"
kubectl -n hadoop-lab get pods -o wide

info "=== Step 5: 验证 HDFS ==="
info "等待 HDFS DataNode 注册..."
sleep 10

# 通过 namenode pod 检查 HDFS
NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}')
info "NameNode Pod: $NAMENODE_POD"
kubectl -n hadoop-lab exec $NAMENODE_POD -- hdfs dfsadmin -report 2>/dev/null || warn "HDFS report not ready yet, will be available shortly."

info "=== 部署完成! ==="
echo ""
echo "========================================="
echo "  Hadoop Lab 部署成功!"
echo "========================================="
echo ""
echo "  HDFS NameNode UI:  http://123.57.146.116:30870"
echo "  YARN ResourceManager UI: http://123.57.146.116:30888"
echo ""
echo "  运行实验:"
echo "    ./experiments/01-hdfs-operations.sh"
echo "    ./experiments/05-pipeline.sh"
echo ""
echo "========================================="
