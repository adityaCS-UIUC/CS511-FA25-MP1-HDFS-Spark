#!/bin/bash
set -euo pipefail
export JAVA_HOME=/usr/local/openjdk-8
HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop

# SSH for this node
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Same Hadoop configs as main
cat > ${HADOOP_CONF_DIR}/core-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://main:9000</value>
  </property>
  <property>
    <name>io.file.buffer.size</name>
    <value>131072</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/tmp/hadoop-data/tmp</value>
  </property>
</configuration>
EOF

cat > ${HADOOP_CONF_DIR}/hdfs-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///tmp/hadoop-data/dfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///tmp/hadoop-data/dfs/datanode</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.permissions.enabled</name>
    <value>false</value>
  </property>
</configuration>
EOF

cat > ${HADOOP_CONF_DIR}/workers <<'EOF'
main
worker1
worker2
EOF

echo "export JAVA_HOME=/usr/local/openjdk-8" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
