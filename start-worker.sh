#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# CRITICAL: Set all environment variables first
export JAVA_HOME=/usr/local/openjdk-8
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH
export HDFS_DATANODE_USER="root"

# Wait for namenode to be ready (give main time to start namenode)
echo "Waiting for NameNode to be ready..."
sleep 15

# Test if NameNode is accessible
until hdfs dfsadmin -safemode get 2>/dev/null | grep -q "Safe mode is OFF"; do
    echo "Waiting for NameNode to exit safe mode..."
    sleep 5
done

# Start DataNode
echo "Starting DataNode on $(hostname)..."
hdfs --daemon start datanode

# Wait and verify datanode started
sleep 5
if jps | grep -q DataNode; then
    echo "DataNode started successfully on $(hostname)"
else
    echo "ERROR: DataNode failed to start on $(hostname)"
    cat $HADOOP_HOME/logs/hadoop-*-datanode-*.log | tail -20
fi

# Start Spark Worker
echo "Starting Spark Worker on $(hostname)..."
export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=1g

# Wait for Spark master to be ready
until nc -z main 7077; do
    echo "Waiting for Spark Master to be ready..."
    sleep 3
done

$SPARK_HOME/sbin/start-worker.sh spark://main:7077

# Wait and verify worker started
sleep 5
if jps | grep -q Worker; then
    echo "Spark Worker started successfully on $(hostname)"
else
    echo "ERROR: Spark Worker failed to start on $(hostname)"
    cat $SPARK_HOME/logs/spark-*-worker-*.out | tail -20
fi

# Keep the container running
tail -f /dev/null