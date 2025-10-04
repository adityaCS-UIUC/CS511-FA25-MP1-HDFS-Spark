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

# HDFS users
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root

# Spark: force hostnames
export SPARK_LOCAL_HOSTNAME=main
export SPARK_LOCAL_IP="$(getent hosts main | awk '{print $1}')"

# Clean any stale Spark worker dirs/PIDs/logs on this node
rm -rf /opt/spark/work/* /tmp/spark* /tmp/spark-* /var/tmp/spark* 2>/dev/null || true

# Stop Spark (if previously started with wrong host)
$SPARK_HOME/sbin/stop-worker.sh || true
$SPARK_HOME/sbin/stop-master.sh || true

# Format NameNode on first boot
if [ ! -d "/tmp/hadoop-data/dfs/namenode/current" ]; then
  echo "Formatting NameNode..."
  hdfs namenode -format -force -nonInteractive
fi

# Start HDFS
$HADOOP_HOME/sbin/start-dfs.sh

# Start Spark master on hostname "main"
$SPARK_HOME/sbin/start-master.sh --host main -p 7077 --webui-port 8080

# Start a worker on main too (we want 3 executors total)
$SPARK_HOME/sbin/start-worker.sh --host main spark://main:7077 --webui-port 8081

# Keep alive
tail -f /dev/null