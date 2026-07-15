# Hadoop Lab

HDFS & YARN/MapReduce cluster deployed on any Kubernetes (K3s/K8s) cluster.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  HDFS (Distributed File System)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ NameNode │  │DataNode 1│  │DataNode 2│  ...     │
│  │ (NN)     │  │ (DN)     │  │ (DN)     │          │
│  └──────────┘  └──────────┘  └──────────┘          │
├─────────────────────────────────────────────────────┤
│  YARN (Resource Management & Job Scheduling)        │
│  ┌────────────────┐  ┌────────────────────┐         │
│  │ResourceManager │  │  NodeManager × N   │         │
│  │ (RM)           │  │  (NM per node)     │         │
│  └────────────────┘  └────────────────────┘         │
└─────────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **NameNode (NN)** | HDFS metadata server — directory tree, block locations |
| **DataNode (DN)** | Stores actual HDFS blocks on disk |
| **ResourceManager (RM)** | YARN global resource scheduler — allocates CPU/memory |
| **NodeManager (NM)** | Per-node YARN agent — launches/manages containers |

## Prerequisites

- **Kubernetes cluster** — any K8s distribution (K3s, Kind, Minikube, production K8s)
  - At least **2 worker nodes** recommended (single-node works too)
  - CPU: 4+ cores total, Memory: 4GB+ total
- **kubectl** connected to the cluster
- **StorageClass** (default `local-path` for K3s, or any StorageClass — change PVC templates if needed)

## Quick Start

```bash
# Deploy everything
./deploy.sh

# Check status
kubectl -n hadoop-lab get pods -o wide

# Run a MapReduce wordcount
kubectl -n hadoop-lab exec hdfs-namenode-0 -- hdfs dfs -mkdir -p /input
kubectl -n hadoop-lab exec hdfs-namenode-0 -- hdfs dfs -put /opt/hadoop/etc/hadoop/*.xml /input/
kubectl -n hadoop-lab exec hdfs-namenode-0 -- yarn jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar wordcount /input /output
kubectl -n hadoop-lab exec hdfs-namenode-0 -- hdfs dfs -cat /output/part-r-00000

# Run experiment scripts
./experiments/01-hdfs-operations.sh
./experiments/05-pipeline.sh

# Clean up everything
./cleanup.sh
```

## Access Web UIs

Services are exposed via NodePort on any cluster node IP:

| Service | Port |
|---------|------|
| HDFS NameNode | `30870` |
| YARN ResourceManager | `30888` |

```bash
# Example: find your node IP and open in browser
kubectl get nodes -o wide
# Then visit http://<node-ip>:30870
```

## Resource Requirements

| Component | Request | Limit |
|-----------|---------|-------|
| NameNode | 512MB RAM, 200m CPU | 768MB RAM, 500m CPU |
| DataNode (×3) | 256MB RAM, 100m CPU | 384MB RAM, 300m CPU |
| ResourceManager | 512MB RAM, 200m CPU | 768MB RAM, 500m CPU |
| NodeManager (×2) | 384MB RAM, 100m CPU | 640MB RAM, 500m CPU |

## Configuration

Hadoop config files live in the `hadoop-config` ConfigMap. Edit and reapply:

```bash
# Edit configmap.yaml locally, then
kubectl apply -f k8s/configmap.yaml
kubectl -n hadoop-lab delete pod -l app=yarn-nodemanager
kubectl -n hadoop-lab delete pod -l app=yarn-resourcemanager
kubectl -n hadoop-lab delete pod hdfs-namenode-0
```

## Custom Image

Pre-built image: `ghcr.io/bojay576/hadoop-lab:latest`

To build your own:

```bash
docker build -t your-registry/hadoop-lab:latest -f docker/Dockerfile docker/
docker push your-registry/hadoop-lab:latest
# Update image tag in all k8s/*.yaml files
```

## Project Structure

```
├── deploy.sh                  # One-click deployment
├── cleanup.sh                 # One-click cleanup
├── k8s/
│   ├── namespace.yaml         # hadoop-lab namespace
│   ├── configmap.yaml         # All Hadoop XML configs
│   ├── hdfs-namenode.yaml     # NameNode StatefulSet + Service
│   ├── hdfs-datanode.yaml     # DataNode DaemonSet
│   ├── yarn-resourcemanager.yaml  # ResourceManager Deployment + Service
│   └── yarn-nodemanager.yaml  # NodeManager DaemonSet
├── docker/
│   ├── Dockerfile             # Based on apache/hadoop:3.3.6
│   └── entrypoint.sh          # Entrypoint (role-based dispatch)
└── experiments/
    ├── 01-hdfs-operations.sh  # Basic HDFS commands
    ├── 02-generate-data.py    # Data generation
    ├── 03-wordcount.sh        # MapReduce wordcount
    ├── 04-log-analyzer/       # Custom MR log analyzer
    └── 05-pipeline.sh         # Full data pipeline
```
