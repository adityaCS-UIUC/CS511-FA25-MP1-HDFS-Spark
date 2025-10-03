#!/bin/bash
set -e

function test_spark_q1() {
  docker compose -f cs511p1-compose.yaml cp resources/active_executors.scala main:/active_executors.scala
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    cat /active_executors.scala | spark-shell --master spark://main:7077'
}

function test_spark_q2() {
  docker compose -f cs511p1-compose.yaml cp resources/pi.scala main:/pi.scala
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    cat /pi.scala | spark-shell --master spark://main:7077'
}

function test_spark_q3() {
  docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    hdfs dfs -mkdir -p /test && \
    hdfs dfs -put -f /test_fox.txt /test/fox.txt && \
    echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | spark-shell --master spark://main:7077'
}

function test_spark_q4() {
  docker compose -f cs511p1-compose.yaml cp resources/spark-terasort-1.2.jar main:/spark-terasort-1.2.jar
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    hdfs dfs -rm -r -f /spark/tera-in /spark/tera-out /spark/tera-val >/dev/null 2>&1 || true; \
    spark-submit --master spark://main:7077 \
      --class com.github.ehiggs.spark.terasort.TeraGen /spark-terasort-1.2.jar 50m hdfs://main:9000/spark/tera-in && \
    spark-submit --master spark://main:7077 \
      --class com.github.ehiggs.spark.terasort.TeraSort /spark-terasort-1.2.jar \
      hdfs://main:9000/spark/tera-in hdfs://main:9000/spark/tera-out && \
    spark-submit --master spark://main:7077 \
      --class com.github.ehiggs.spark.terasort.TeraValidate /spark-terasort-1.2.jar \
      hdfs://main:9000/spark/tera-out hdfs://main:9000/spark/tera-val && echo PASS'
}

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
mkdir -p out

echo -n "Testing Spark Q1 ..."
if test_spark_q1 > out/test_spark_q1.out 2>&1 && grep -q "worker1" out/test_spark_q1.out && grep -q "worker2" out/test_spark_q1.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing Spark Q2 ..."
if test_spark_q2 > out/test_spark_q2.out 2>&1 && grep -q "Pi is roughly" out/test_spark_q2.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing Spark Q3 ..."
if test_spark_q3 > out/test_spark_q3.out 2>&1 && grep -q "Array(The quick brown fox jumps over the lazy dog)" out/test_spark_q3.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing Spark Q4 ..."
if test_spark_q4 > out/test_spark_q4.out 2>&1 && grep -q "PASS" out/test_spark_q4.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi
