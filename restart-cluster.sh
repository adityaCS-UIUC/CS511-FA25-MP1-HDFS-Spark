#!/bin/bash

echo "Stopping all containers..."
docker compose -f cs511p1-compose.yaml down

echo "Starting containers..."
docker compose -f cs511p1-compose.yaml up -d

echo "Waiting for containers to start..."
sleep 10

echo "Checking container status..."
docker compose -f cs511p1-compose.yaml ps

echo "Checking HDFS status..."
docker compose -f cs511p1-compose.yaml exec main hdfs dfsadmin -report | grep "Live datanodes"

echo "Checking Spark processes on main..."
docker compose -f cs511p1-compose.yaml exec main ps aux | grep spark

echo "Checking Spark processes on worker1..."
docker compose -f cs511p1-compose.yaml exec worker1 ps aux | grep spark

echo "Checking Spark processes on worker2..."
docker compose -f cs511p1-compose.yaml exec worker2 ps aux | grep spark

echo "If Spark workers are not running, you may need to start them manually:"
echo "docker compose -f cs511p1-compose.yaml exec worker1 bash -c 'export SPARK_HOME=/opt/spark && export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin && export JAVA_HOME=/usr/local/openjdk-8/jre && \$SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker --webui-port 8081 spark://main:7077 &'"
echo "docker compose -f cs511p1-compose.yaml exec worker2 bash -c 'export SPARK_HOME=/opt/spark && export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin && export JAVA_HOME=/usr/local/openjdk-8/jre && \$SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker --webui-port 8081 spark://main:7077 &'"
