#!/bin/bash
export JAVA_HOME=/usr/local/openjdk-8/jre
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark main here
cat > ${HADOOP_CONF_DIR}/core-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://main:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/tmp/hadoop-data</value>
    </property>
</configuration>
EOF

# --- 2. hdfs-site.xml ---
cat > ${HADOOP_CONF_DIR}/hdfs-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
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
        <value>2</value>
    </property>
</configuration>
EOF

# --- 3. workers file ---
cat > ${HADOOP_CONF_DIR}/workers <<EOF
main
worker1
worker2
EOF


JAVA_PATH="/usr/local/openjdk-8/jre"
# --- 4. hadoop-env.sh (Set JAVA_HOME inside Hadoop config) ---
# Use sed to replace the default JAVA_HOME placeholder
echo "export JAVA_HOME=/usr/local/openjdk-8/jre" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

# Setup Spark configuration
mkdir -p ${SPARK_HOME}/conf
cat > ${SPARK_HOME}/conf/spark-defaults.conf <<EOF
spark.master                     spark://main:7077
spark.executor.memory            1g
spark.driver.memory              1g
spark.serializer                 org.apache.spark.serializer.KryoSerializer
EOF

# Setup Spark environment
cat > ${SPARK_HOME}/conf/spark-env.sh <<EOF
export JAVA_HOME=/usr/local/openjdk-8/jre
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR}
export SPARK_LOCAL_IP=main
EOF

# Create Spark workers file
cat > ${SPARK_HOME}/conf/workers <<EOF
main
worker1
worker2
EOF