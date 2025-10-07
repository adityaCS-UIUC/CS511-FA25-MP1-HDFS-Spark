#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Match the JAVA_HOME from setup scripts
export JAVA_HOME=/usr/local/openjdk-8/jre
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH
export HDFS_DATANODE_USER="root"

# Create required directories
mkdir -p /tmp/hadoop-data/dfs/datanode

# Wait for namenode
echo "Waiting for NameNode on $(hostname)..."
sleep 15

# Start DataNode
echo "Starting DataNode on $(hostname)..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

sleep 8
echo "DataNode status:"
jps | grep DataNode || echo "DataNode NOT running!"

# Start Spark Worker  
echo "Starting Spark Worker on $(hostname)..."
export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')

sleep 5
$SPARK_HOME/sbin/start-worker.sh spark://main:7077

sleep 8
echo "Spark Worker status:"
jps | grep Worker || echo "Worker NOT running!"

echo "Final processes on $(hostname):"
jps

# Keep container running
tail -f /dev/null