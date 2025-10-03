#!/bin/bash
set -euo pipefail

# SSH agent for intra-cluster ops
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa || true

export JAVA_HOME=/usr/local/openjdk-8
export HDFS_DATANODE_USER=root

echo "Starting HDFS DataNode ..."
${HADOOP_HOME}/sbin/hadoop-daemon.sh start datanode

echo "Starting Spark Worker (to master spark://main:7077) ..."
/opt/spark/sbin/start-worker.sh spark://main:7077

# Keep container alive
tail -f /dev/null
