#!/bin/bash
# =============================================================
# 实验3: WordCount 词频统计 (经典 MapReduce 示例)
# =============================================================
set -e

NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}')

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

hdfs_fs() {
    kubectl -n hadoop-lab exec $NAMENODE_POD -- hdfs dfs "$@"
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  实验3: WordCount 词频统计${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# 1. 准备输入数据
echo -e "${YELLOW}[Step 1] 准备输入数据${NC}"
kubectl -n hadoop-lab exec $NAMENODE_POD -- bash -c "
    mkdir -p /tmp/wc-input
    cat > /tmp/wc-input/sample1.txt << 'EOF'
Hadoop is a framework for distributed storage and processing
of big data sets using the MapReduce programming model
HDFS provides high throughput access to application data
MapReduce splits tasks into small work units
YARN manages computing resources in a cluster
EOF

    cat > /tmp/wc-input/sample2.txt << 'EOF'
Apache Hadoop is an open source framework
It supports the processing of large data sets
HDFS and MapReduce are the core components
Hadoop provides reliable and scalable storage
The framework handles failures at the application layer
EOF
"
echo "创建示例文件完成"
echo ""

# 2. 上传到 HDFS
echo -e "${YELLOW}[Step 2] 上传数据到 HDFS${NC}"
hdfs_fs -mkdir -p /user/hadoop/wc-input
hdfs_fs -put -f /tmp/wc-input/ /user/hadoop/wc-input/
echo "上传完成! HDFS 文件列表:"
hdfs_fs -ls /user/hadoop/wc-input/
echo ""

# 3. 运行 WordCount MapReduce
echo -e "${YELLOW}[Step 3] 提交 WordCount MapReduce 作业${NC}"
echo "命令: hadoop jar hadoop-mapreduce-examples.jar wordcount /user/hadoop/wc-input /user/hadoop/wc-output"
echo ""

# 删除旧输出
hdfs_fs -rm -r -f /user/hadoop/wc-output 2>/dev/null || true

kubectl -n hadoop-lab exec $NAMENODE_POD -- bash -c "
    hadoop jar \$(find /opt/hadoop -name 'hadoop-mapreduce-examples*.jar' | head -1) \
        wordcount \
        /user/hadoop/wc-input \
        /user/hadoop/wc-output
"

echo ""

# 4. 查看结果
echo -e "${YELLOW}[Step 4] 查看 WordCount 结果${NC}"
echo "输出文件列表:"
hdfs_fs -ls /user/hadoop/wc-output/
echo ""
echo "词频统计结果 (按频率降序):"
echo "-----------------------------------"
hdfs_fs -cat /user/hadoop/wc-output/part-r-00000 | sort -t$'\t' -k2 -nr
echo "-----------------------------------"
echo ""

echo -e "${GREEN}=== 实验3 完成! ===${NC}"
echo "WordCount 是 MapReduce 最经典的示例:"
echo "  - Map 阶段: 将文本拆分为单词，输出 (word, 1)"
echo "  - Shuffle 阶段: 将相同单词聚合到一起"
echo "  - Reduce 阶段: 对每个单词的计数求和"
