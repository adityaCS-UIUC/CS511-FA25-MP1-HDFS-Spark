#!/bin/bash
set -euo pipefail
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

export JAVA_HOME=/usr/local/openjdk-8
export HADOOP_HOME=/opt/hadoop
export SPARK_HOME=/opt/spark

/opt/hadoop/bin/hdfs --daemon start datanode || true
/opt/spark/sbin/start-worker.sh spark://main:7077 || true

exec bash
