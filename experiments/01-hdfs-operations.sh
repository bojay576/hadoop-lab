#!/bin/bash
# =============================================================
# 实验1: HDFS 基本操作
# 学习 HDFS 文件系统的基本命令
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}')

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

hdfs_cmd() {
    kubectl -n hadoop-lab exec $NAMENODE_POD -- hdfs "$@"
}

hdfs_fs_cmd() {
    kubectl -n hadoop-lab exec $NAMENODE_POD -- hdfs dfs "$@"
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  实验1: HDFS 基本操作${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# 1. 查看 HDFS 状态
echo -e "${YELLOW}[Step 1] 查看 HDFS 集群状态${NC}"
hdfs_cmd dfsadmin -report
echo ""
read -p "按 Enter 继续..."

# 2. 创建目录
echo -e "${YELLOW}[Step 2] 创建 HDFS 目录${NC}"
echo "hdfs dfs -mkdir -p /user/hadoop/input"
hdfs_fs_cmd -mkdir -p /user/hadoop/input
echo "hdfs dfs -mkdir -p /user/hadoop/output"
hdfs_fs_cmd -mkdir -p /user/hadoop/output
echo "目录创建成功!"
echo ""
read -p "按 Enter 继续..."

# 3. 创建测试文件并上传
echo -e "${YELLOW}[Step 3] 创建测试文件并上传到 HDFS${NC}"
kubectl -n hadoop-lab exec $NAMENODE_POD -- bash -c "
    echo 'Hello Hadoop World' > /tmp/test.txt
    echo 'Big Data is Amazing' >> /tmp/test.txt
    echo 'HDFS stores data across nodes' >> /tmp/test.txt
    echo 'MapReduce processes data in parallel' >> /tmp/test.txt
    cat /tmp/test.txt
"
echo ""
echo "上传文件到 HDFS..."
echo "hdfs dfs -put /tmp/test.txt /user/hadoop/input/"
hdfs_fs_cmd -put -f /tmp/test.txt /user/hadoop/input/
echo "上传成功!"
echo ""
read -p "按 Enter 继续..."

# 4. 查看文件信息
echo -e "${YELLOW}[Step 4] 查看 HDFS 文件信息${NC}"
echo "列出 /user/hadoop/input/ 目录:"
hdfs_fs_cmd -ls /user/hadoop/input/
echo ""
echo "查看文件内容:"
hdfs_fs_cmd -cat /user/hadoop/input/test.txt
echo ""
echo "查看文件块信息:"
hdfs_fs_cmd -stat '%o' /user/hadoop/input/test.txt
echo ""
read -p "按 Enter 继续..."

# 5. 文件操作
echo -e "${YELLOW}[Step 5] HDFS 文件操作${NC}"
echo "复制文件:"
hdfs_fs_cmd -cp /user/hadoop/input/test.txt /user/hadoop/input/test-copy.txt
hdfs_fs_cmd -ls /user/hadoop/input/
echo ""
echo "查看磁盘使用情况:"
hdfs_fs_cmd -du -h /user/hadoop/
echo ""
echo "统计文件行数:"
hdfs_fs_cmd -count /user/hadoop/input/test.txt
echo ""

echo -e "${GREEN}=== 实验1 完成! ===${NC}"
echo "你已学习了:"
echo "  - hdfs dfsadmin: 集群管理"
echo "  - hdfs dfs -mkdir: 创建目录"
echo "  - hdfs dfs -put: 上传文件"
echo "  - hdfs dfs -cat: 查看文件"
echo "  - hdfs dfs -cp: 复制文件"
echo "  - hdfs dfs -du: 磁盘使用"
