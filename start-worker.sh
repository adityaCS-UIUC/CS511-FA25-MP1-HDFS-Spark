#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

export JAVA_HOME=/usr/local/openjdk-8
export HDFS_DATANODE_USER="root"

# Wait for namenode to be ready (give main time to start namenode)
echo "Waiting for NameNode to be ready..."
sleep 10

# Start DataNode
echo "Starting DataNode on $(hostname)..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

# Wait a bit for datanode to initialize
sleep 5

# Start Spark Worker
echo "Starting Spark Worker on $(hostname)..."
export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')
$SPARK_HOME/sbin/start-worker.sh spark://main:7077

# Wait for worker to register
sleep 3

# Keep the container running
tail -f /dev/null