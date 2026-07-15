#!/bin/bash
# =============================================================
# 实验5: 完整数据分析流水线
# 生成数据 -> 上传 HDFS -> 运行多个 MR 分析 -> 汇总结果
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}')

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

hdfs_fs() {
    kubectl -n hadoop-lab exec $NAMENODE_POD -- hdfs dfs "$@"
}

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  实验5: 电商日志完整数据分析流水线${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo "流水线步骤:"
echo "  1. 生成模拟电商访问日志 (10万条)"
echo "  2. 上传日志数据到 HDFS"
echo "  3. 运行 PV/UV 日统计分析"
echo "  4. 运行热门商品排行分析"
echo "  5. 运行用户行为分布分析"
echo "  6. 运行商品类目分布分析"
echo "  7. 汇总并展示所有分析结果"
echo ""
read -p "按 Enter 开始运行..."
echo ""

# ========== Step 1: 生成数据 ==========
echo -e "${YELLOW}[Step 1/7] 生成模拟电商日志数据${NC}"
python3 "$SCRIPT_DIR/02-generate-data.py" 100000 /tmp/ecommerce-access.log
echo ""

# ========== Step 2: 上传到 HDFS ==========
echo -e "${YELLOW}[Step 2/7] 上传数据到 HDFS${NC}"

# 复制数据文件到 namenode pod
kubectl -n hadoop-lab cp /tmp/ecommerce-access.log "$NAMENODE_POD:/tmp/ecommerce-access.log"

hdfs_fs -mkdir -p /user/hadoop/ecommerce/input
hdfs_fs -put -f /tmp/ecommerce-access.log /user/hadoop/ecommerce/input/

echo "HDFS 文件信息:"
hdfs_fs -ls -h /user/hadoop/ecommerce/input/
echo ""

# ========== 构建 LogAnalyzer ==========
echo -e "${YELLOW}[构建] 编译 LogAnalyzer MapReduce 作业${NC}"
bash "$SCRIPT_DIR/04-log-analyzer/build.sh"
echo ""

# ========== Step 3: PV/UV 分析 ==========
echo -e "${YELLOW}[Step 3/7] 运行 PV/UV 日统计分析${NC}"
hdfs_fs -rm -r -f /user/hadoop/ecommerce/pv-uv-output 2>/dev/null || true
kubectl -n hadoop-lab exec $NAMENODE_POD -- hadoop jar /tmp/LogAnalyzer.jar LogAnalyzer \
    pv-uv /user/hadoop/ecommerce/input /user/hadoop/ecommerce/pv-uv-output
echo ""

# ========== Step 4: 热门商品分析 ==========
echo -e "${YELLOW}[Step 4/7] 运行热门商品排行分析${NC}"
hdfs_fs -rm -r -f /user/hadoop/ecommerce/top-products-output 2>/dev/null || true
kubectl -n hadoop-lab exec $NAMENODE_POD -- hadoop jar /tmp/LogAnalyzer.jar LogAnalyzer \
    top-products /user/hadoop/ecommerce/input /user/hadoop/ecommerce/top-products-output
echo ""

# ========== Step 5: 行为分布分析 ==========
echo -e "${YELLOW}[Step 5/7] 运行用户行为分布分析${NC}"
hdfs_fs -rm -r -f /user/hadoop/ecommerce/action-dist-output 2>/dev/null || true
kubectl -n hadoop-lab exec $NAMENODE_POD -- hadoop jar /tmp/LogAnalyzer.jar LogAnalyzer \
    action-dist /user/hadoop/ecommerce/input /user/hadoop/ecommerce/action-dist-output
echo ""

# ========== Step 6: 类目分布分析 ==========
echo -e "${YELLOW}[Step 6/7] 运行商品类目分布分析${NC}"
hdfs_fs -rm -r -f /user/hadoop/ecommerce/category-dist-output 2>/dev/null || true
kubectl -n hadoop-lab exec $NAMENODE_POD -- hadoop jar /tmp/LogAnalyzer.jar LogAnalyzer \
    category-dist /user/hadoop/ecommerce/input /user/hadoop/ecommerce/category-dist-output
echo ""

# ========== Step 7: 汇总结果 ==========
echo -e "${YELLOW}[Step 7/7] 汇总分析结果${NC}"
echo ""

echo -e "${CYAN}========== PV/UV 日统计 ==========${NC}"
hdfs_fs -cat /user/hadoop/ecommerce/pv-uv-output/part-r-00000 | sort
echo ""

echo -e "${CYAN}========== 热门商品 TOP 20 ==========${NC}"
hdfs_fs -cat /user/hadoop/ecommerce/top-products-output/part-r-00000 | sort -t$'\t' -k2 -nr | head -20
echo ""

echo -e "${CYAN}========== 用户行为分布 ==========${NC}"
hdfs_fs -cat /user/hadoop/ecommerce/action-dist-output/part-r-00000 | sort -t$'\t' -k2 -nr
echo ""

echo -e "${CYAN}========== 商品类目分布 ==========${NC}"
hdfs_fs -cat /user/hadoop/ecommerce/category-dist-output/part-r-00000 | sort -t$'\t' -k2 -nr
echo ""

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  数据分析流水线运行完成!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "分析结果存储在 HDFS:"
hdfs_fs -ls -R /user/hadoop/ecommerce/
echo ""
echo "本次实验涵盖了大数据处理的核心流程:"
echo "  1. 数据采集 - 模拟生成电商日志"
echo "  2. 数据存储 - 上传到 HDFS 分布式文件系统"
echo "  3. 数据处理 - 使用 MapReduce 并行计算"
echo "  4. 数据分析 - 多维度统计分析"
echo "  5. 结果输出 - 汇总展示分析结果"
