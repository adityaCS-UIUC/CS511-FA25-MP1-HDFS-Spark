####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

FROM openjdk:8

RUN apt update && \
    apt upgrade --yes && \
    apt install ssh openssh-server --yes

# Setup common SSH key.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/shared_rsa -C common && \
    cat ~/.ssh/shared_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark resources here

# Set Hadoop and Spark versions
ENV HADOOP_VERSION 3.3.6
ENV SPARK_VERSION 3.4.1
ENV HADOOP_HOME /opt/hadoop
ENV SPARK_HOME /opt/spark

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget curl && \
    wget https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz && \
    tar -xvzf hadoop-$HADOOP_VERSION.tar.gz -C /opt && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    rm hadoop-$HADOOP_VERSION.tar.gz && \
    wget https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz && \
    tar -xzf spark-$SPARK_VERSION-bin-hadoop3.tgz -C /opt && \
    ln -s /opt/spark-$SPARK_VERSION-bin-hadoop3 /opt/spark && \
    rm spark-$SPARK_VERSION-bin-hadoop3.tgz

# Set environment variables
ENV PATH $HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop

# Create necessary HDFS directories and set permissions
RUN mkdir -p /tmp/hadoop-data/dfs/namenode \
           /tmp/hadoop-data/dfs/datanode \
           /tmp/hadoop-data/tmp \
           $HADOOP_HOME/logs
RUN chown -R root:root /tmp/hadoop-data $HADOOP_HOME