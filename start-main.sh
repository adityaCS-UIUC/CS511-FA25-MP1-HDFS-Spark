#!/bin/bash
set -euo pipefail

# SSH baseline
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

# Push our key to workers (idempotent)
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker1 || true
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker2 || true

# Env (use absolute paths remotely)
export JAVA_HOME=/usr/local/openjdk-8
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$PATH"

# Format NN once
if [ ! -f /data/nn/current/VERSION ]; then
  /opt/hadoop/bin/hdfs namenode -format -force -nonInteractive
fi

# Start HDFS daemons
/opt/hadoop/bin/hdfs --daemon start namenode
/opt/hadoop/bin/hdfs --daemon start datanode
ssh worker1 -t "/opt/hadoop/bin/hdfs --daemon start datanode || true"
ssh worker2 -t "/opt/hadoop/bin/hdfs --daemon start datanode || true"

# Start Spark standalone
/opt/spark/sbin/start-master.sh
/opt/spark/sbin/start-worker.sh spark://main:7077
ssh worker1 -t "/opt/spark/sbin/start-worker.sh spark://main:7077 || true"
ssh worker2 -t "/opt/spark/sbin/start-worker.sh spark://main:7077 || true"

# Keep container alive
exec bash
