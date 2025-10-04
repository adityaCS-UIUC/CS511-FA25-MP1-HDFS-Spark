#!/bin/bash

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

export JAVA_HOME=/usr/local/openjdk-8
export SPARK_HOME=/opt/spark
export PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

$SPARK_HOME/sbin/stop-worker.sh || true
pkill -f org.apache.spark.deploy.worker.Worker || true
rm -rf /opt/spark/work/* /tmp/spark* /var/tmp/spark* 2>/dev/null || true

/opt/spark/sbin/start-worker.sh --host "$(hostname)" spark://main:7077

export SPARK_LOCAL_HOSTNAME="$(hostname)"
export SPARK_LOCAL_IP=$(getent hosts "$(hostname)" | awk '{print $1}')

# Start HDFS/Spark worker here
export JAVA_HOME="/usr/local/openjdk-8/jre"

export HDFS_DATANODE_USER="root"
# bash
echo "Starting DataNode..."
# Start the DataNode service
$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

# Keep the container running
tail -f /dev/null