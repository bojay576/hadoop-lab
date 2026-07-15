#!/bin/bash
set -e

echo "Starting Hadoop role: $HADOOP_ROLE"

# Wait for NameNode DNS
if [ "$HADOOP_ROLE" = "datanode" ] || [ "$HADOOP_ROLE" = "resourcemanager" ] || [ "$HADOOP_ROLE" = "nodemanager" ]; then
    echo "Waiting for NameNode to be ready..."
    for i in $(seq 1 60); do
        if nslookup hdfs-namenode-0.hdfs-namenode.hadoop-lab.svc.cluster.local >/dev/null 2>&1; then
            echo "NameNode DNS resolved."
            break
        fi
        echo "Attempt $i/60: NameNode not yet ready, retrying in 5s..."
        sleep 5
    done
fi

case "$HADOOP_ROLE" in
    namenode)
        echo "Starting HDFS NameNode..."
        # Format namenode if not already formatted
        if [ ! -d /data/hdfs/namenode/current ]; then
            echo "Formatting NameNode..."
            hdfs namenode -format -nonInteractive -force
        fi
        exec hdfs namenode
        ;;
    datanode)
        echo "Starting HDFS DataNode..."
        exec hdfs datanode
        ;;
    resourcemanager)
        echo "Starting YARN ResourceManager..."
        exec yarn resourcemanager
        ;;
    nodemanager)
        echo "Starting YARN NodeManager..."
        # Wait for ResourceManager
        echo "Waiting for ResourceManager to be ready..."
        for i in $(seq 1 60); do
            if curl -sf http://yarn-resourcemanager:8088/ws/v1/cluster/info >/dev/null 2>&1; then
                echo "ResourceManager is ready."
                break
            fi
            echo "Attempt $i/60: ResourceManager not yet ready, retrying in 5s..."
            sleep 5
        done
        exec yarn nodemanager
        ;;
    *)
        echo "Unknown role: $HADOOP_ROLE"
        echo "Available roles: namenode, datanode, resourcemanager, nodemanager"
        exit 1
        ;;
esac
