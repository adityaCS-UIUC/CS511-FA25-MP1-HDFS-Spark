####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

FROM openjdk:8

RUN apt update && \
    apt upgrade --yes && \
    DEBIAN_FRONTEND=noninteractive apt install --yes ssh openssh-server curl wget tar bash procps net-tools

# Setup common SSH key.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/shared_rsa -C common && \    mkdir -p ~/.ssh && cat ~/.ssh/shared_rsa.pub >> ~/.ssh/authorized_keys && \    chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# ---------- Hadoop & Spark Versions ----------
ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.4.1

# ---------- Hadoop ----------
RUN mkdir -p /opt && \    wget -q https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \    ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \    rm hadoop-${HADOOP_VERSION}.tar.gz
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop

# ---------- Spark (pre-built for Hadoop 3) ----------
RUN wget -q https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz -C /opt && \    ln -s /opt/spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark && \    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz
ENV SPARK_HOME=/opt/spark

# ---------- Env ----------
ENV JAVA_HOME=/usr/local/openjdk-8
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}

# HDFS runtime dirs
RUN mkdir -p /tmp/hadoop-data/dfs/namenode /tmp/hadoop-data/dfs/datanode /tmp/hadoop-data/tmp ${HADOOP_HOME}/logs

# Quiet SSH first-connection prompts inside the containers
RUN printf "Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile=/dev/null\n" >> /root/.ssh/config
