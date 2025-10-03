#!/bin/bash
set -euo pipefail

# Start SSH and exchange keys
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa || true
# allow passwordless to workers
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker1 || true
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker2 || true

export JAVA_HOME=/usr/local/openjdk-8
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root

# Format NN if first run
if [ ! -d "/tmp/hadoop-data/dfs/namenode/current" ]; then
  echo "Formatting NameNode ..."
  hdfs namenode -format -force -nonInteractive
fi

echo "Starting HDFS (NameNode on main; DataNodes on main, worker1, worker2) ..."
${HADOOP_HOME}/sbin/start-dfs.sh

# ----- Spark Master + local worker on main -----
export SPARK_NO_DAEMONIZE=1
# Start master
/opt/spark/sbin/start-master.sh -h main -p 7077 --webui-port 8080
# Start a worker on main (3rd worker)
/opt/spark/sbin/start-worker.sh spark://main:7077 --webui-port 8081

# Keep container alive
tail -f /dev/null
