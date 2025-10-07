#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# CRITICAL: Set all environment variables first
export JAVA_HOME=/usr/local/openjdk-8/jre
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH
export HDFS_DATANODE_USER="root"

echo "========================================"
echo "Starting services on $(hostname)"
echo "HADOOP_HOME: $HADOOP_HOME"
echo "SPARK_HOME: $SPARK_HOME"
echo "JAVA_HOME: $JAVA_HOME"
echo "========================================"

# Create datanode directory if it doesn't exist
mkdir -p /tmp/hadoop-data/dfs/datanode

# Wait for namenode to be ready
echo "Waiting for NameNode to be ready..."
sleep 15

# Try to connect to namenode
echo "Testing connection to NameNode..."
until hdfs dfsadmin -report >/dev/null 2>&1; do
    echo "NameNode not ready yet, waiting..."
    sleep 5
done
echo "NameNode is accessible!"

# Start DataNode with explicit command
echo "Starting DataNode on $(hostname)..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

# Wait and check if it started
sleep 8

if jps | grep -q DataNode; then
    echo "✓ DataNode started successfully on $(hostname)"
else
    echo "✗ ERROR: DataNode failed to start on $(hostname)"
    echo "Checking logs..."
    if [ -d "$HADOOP_HOME/logs" ]; then
        echo "Recent DataNode log entries:"
        find $HADOOP_HOME/logs -name "*datanode*.log" -exec tail -30 {} \;
    fi
fi

# Start Spark Worker
echo "Starting Spark Worker on $(hostname)..."
export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=1g

# Wait for Spark master to be ready
echo "Waiting for Spark Master..."
until nc -z main 7077 2>/dev/null; do
    echo "Spark Master not ready yet, waiting..."
    sleep 3
done
echo "Spark Master is accessible!"

$SPARK_HOME/sbin/start-worker.sh spark://main:7077

# Wait and verify
sleep 8

if jps | grep -q Worker; then
    echo "✓ Spark Worker started successfully on $(hostname)"
else
    echo "✗ ERROR: Spark Worker failed to start on $(hostname)"
    if [ -d "$SPARK_HOME/logs" ]; then
        echo "Recent Spark Worker log entries:"
        find $SPARK_HOME/logs -name "*worker*.out" -exec tail -30 {} \;
    fi
fi

echo "========================================"
echo "Final status on $(hostname):"
jps
echo "========================================"

# Keep the container running
tail -f /dev/null