#!/bin/bash
# =============================================================
# 构建 LogAnalyzer MapReduce 作业
# 在 NameNode Pod 内编译并打包为 JAR
# =============================================================
set -e

NAMENODE_POD=$(kubectl -n hadoop-lab get pods -l app=hdfs-namenode -o jsonpath='{.items[0].metadata.name}')
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}构建 LogAnalyzer MapReduce 作业${NC}"

# 将 Java 文件复制到 namenode pod
echo "复制源码到 NameNode Pod..."
kubectl -n hadoop-lab cp "$SCRIPT_DIR/LogAnalyzer.java" "$NAMENODE_POD:/tmp/LogAnalyzer.java"

# 在 Pod 内编译
echo "编译 Java 源码..."
kubectl -n hadoop-lab exec $NAMENODE_POD -- bash -c "
    mkdir -p /tmp/log-analyzer-classes

    # 收集所有 hadoop jar 作为 classpath
    HADOOP_CP=\$(find /opt/hadoop/share/hadoop -name '*.jar' | tr '\n' ':')

    javac -cp \${HADOOP_CP} \
        -d /tmp/log-analyzer-classes \
        /tmp/LogAnalyzer.java

    echo '编译成功!'

    # 打包为 JAR
    cd /tmp/log-analyzer-classes
    jar cf /tmp/LogAnalyzer.jar *
    echo '打包完成: /tmp/LogAnalyzer.jar'
"

echo -e "${GREEN}构建完成!${NC}"
echo "JAR 文件位于 NameNode Pod: /tmp/LogAnalyzer.jar"
echo ""
echo "运行示例:"
echo "  kubectl -n hadoop-lab exec $NAMENODE_POD -- hadoop jar /tmp/LogAnalyzer.jar LogAnalyzer pv-uv /user/hadoop/ecommerce/input /user/hadoop/ecommerce/pv-uv-output"
