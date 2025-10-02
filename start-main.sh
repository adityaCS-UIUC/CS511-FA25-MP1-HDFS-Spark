#!/bin/bash
set -euo pipefail

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

# Exchange SSH keys.
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker1
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker2

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Start HDFS/Spark main here
export JAVA_HOME=/usr/local/openjdk-8
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$PATH

# Format NN once (idempotent)
if [ ! -f /data/nn/current/VERSION ]; then
  hdfs namenode -format -force -nonInteractive
fi

# Start HDFS daemons: NN on main, DN on all three
hdfs --daemon start namenode
hdfs --daemon start datanode
ssh worker1 -t "hdfs --daemon start datanode"
ssh worker2 -t "hdfs --daemon start datanode"

# Give HDFS a sec to stabilize
sleep 3

# Start Spark Standalone: master + worker on all three
${SPARK_HOME}/sbin/start-master.sh
${SPARK_HOME}/sbin/start-worker.sh spark://main:7077
ssh worker1 -t "${SPARK_HOME}/sbin/start-worker.sh spark://main:7077"
ssh worker2 -t "${SPARK_HOME}/sbin/start-worker.sh spark://main:7077"

# Keep container alive & interactive
exec bash
