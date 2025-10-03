#!/bin/bash
set -euo pipefail
export JAVA_HOME=/usr/local/openjdk-8

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Hadoop core-site / hdfs-site
cat > /opt/hadoop/etc/hadoop/core-site.xml <<'XML'
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://main:9000</value>
  </property>
</configuration>
XML

cat > /opt/hadoop/etc/hadoop/hdfs-site.xml <<'XML'
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///data/nn</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///data/dn</value>
  </property>
  <property>
    <name>dfs.namenode.rpc-address</name>
    <value>main:9000</value>
  </property>
  <property>
    <name>dfs.namenode.http-address</name>
    <value>0.0.0.0:9870</value>
  </property>
</configuration>
XML

mkdir -p /data/nn /data/dn

# Workers list for Hadoop & Spark
printf "main\nworker1\nworker2\n" | tee /opt/hadoop/etc/hadoop/workers >/dev/null

mkdir -p /opt/spark/conf
printf "main\nworker1\nworker2\n" | tee /opt/spark/conf/workers >/dev/null

cat > /opt/spark/conf/spark-env.sh <<'SH'
export SPARK_MASTER_HOST=main
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=1G
SH
chmod +x /opt/spark/conf/spark-env.sh
