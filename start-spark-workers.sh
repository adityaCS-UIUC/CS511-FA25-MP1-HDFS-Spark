#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

echo "Starting Spark worker on worker1..."
docker compose -f cs511p1-compose.yaml exec worker1 bash -c 'export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && export JAVA_HOME=/usr/local/openjdk-8/jre && $SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker --webui-port 8081 spark://main:7077 &'

echo "Starting Spark worker on worker2..."
docker compose -f cs511p1-compose.yaml exec worker2 bash -c 'export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && export JAVA_HOME=/usr/local/openjdk-8/jre && $SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker --webui-port 8081 spark://main:7077 &'

echo "Waiting for workers to start..."
sleep 5

echo "Checking Spark processes..."
echo "=== Main ==="
docker compose -f cs511p1-compose.yaml exec main ps aux | grep spark

echo "=== Worker1 ==="
docker compose -f cs511p1-compose.yaml exec worker1 ps aux | grep spark

echo "=== Worker2 ==="
docker compose -f cs511p1-compose.yaml exec worker2 ps aux | grep spark

echo "Testing Spark Q1..."
docker compose -f cs511p1-compose.yaml cp resources/active_executors.scala main:/active_executors.scala
docker compose -f cs511p1-compose.yaml exec main bash -c 'export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && cat /active_executors.scala | spark-shell --master spark://main:7077' | grep "res0:"
