#!/bin/bash
set -euo pipefail

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa || true
####################################################################################

export JAVA_HOME="/usr/local/openjdk-8"
export HADOOP_HOME="/opt/hadoop"
export SPARK_HOME="/opt/spark"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"

# Force worker to register by hostname (worker1 / worker2)
export SPARK_LOCAL_HOSTNAME="$(hostname)"
export SPARK_LOCAL_IP="$(getent hosts "$(hostname)" | awk '{print $1}')"

# Stop any old worker and kill stragglers that registered by IP
$SPARK_HOME/sbin/stop-worker.sh || true
pkill -f 'org.apache.spark.deploy.worker.Worker' || true

# Clean stale worker state that may preserve wrong identity/ports
rm -rf /opt/spark/work/* /tmp/spark* /tmp/spark-* /var/tmp/spark* 2>/dev/null || true

# Start the worker with explicit host
$SPARK_HOME/sbin/start-worker.sh --host "$(hostname)" spark://main:7077

# Also run HDFS DataNode
export HDFS_DATANODE_USER="root"
echo "Starting DataNode..."
$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

tail -f /dev/null