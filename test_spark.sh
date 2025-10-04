#!/bin/bash

# Back up the current script (just in case)
cp -f test_spark.sh test_spark.sh.bak

# Overwrite the Q1 function with a robust inline version (no external .scala file)
awk '
  BEGIN{infunc=0}
  /^function[ \t]+test_spark_q1\(\)[ \t]*\{/ {print; infunc=1; print "  docker compose -f cs511p1-compose.yaml exec main bash -lc '\\''"; print "    /opt/spark/bin/spark-shell --master spark://main:7077 -e \""; print "      sc.parallelize(1 to 1000,3).count"; print "      val names=Array(\\\"main\\\",\\\"worker1\\\",\\\"worker2\\\")"; print "      val nameToIp=names.flatMap(n=>scala.util.Try(java.net.InetAddress.getByName(n).getHostAddress).toOption.map(ip=>(n,ip))).toMap"; print "      val ipToName=nameToIp.map(_.swap)"; print "      val endpoints=sc.getExecutorMemoryStatus.keys.toSeq"; print "      val hosts=endpoints.map(_.split(\\\":\\\")(0)).distinct"; print "      val mapped=hosts.map(h=>ipToName.getOrElse(h,h)).distinct"; print "      val drv=sc.getConf.getOption(\\\"spark.driver.host\\\").map(h=>ipToName.getOrElse(h,h)).getOrElse(\\\"main\\\")"; print "      mapped.filterNot(_==drv).sorted.foreach(println)"; print "    \""; print "  '\\''"; next}
  infunc==1 && /\}/ {infunc=0; print; next}
  infunc==0 {print}
' test_spark.sh > test_spark.sh.tmp && mv test_spark.sh.tmp test_spark.sh && chmod +x test_spark.sh

function test_spark_q2() {
    docker compose -f cs511p1-compose.yaml cp resources/pi.scala main:/pi.scala
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        cat /pi.scala | spark-shell --master spark://main:7077'

}

function test_spark_q3() {
    docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt'
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | \
        spark-shell --master spark://main:7077'

}

function test_spark_q4() {
    docker compose -f cs511p1-compose.yaml cp resources/spark-terasort-1.2.jar \
        main:/spark-terasort-1.2.jar
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraGen local:///spark-terasort-1.2.jar \
        100m hdfs://main:9000/spark/tera-in'
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraSort local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-in hdfs://main:9000/spark/tera-out'
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraValidate local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-out hdfs://main:9000/spark/tera-val'
}

function print_score() {
    echo "-----------------------------------"
    echo "Result: $@"
}

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p out

echo -n "Testing Spark Q1 ..."
test_spark_q1 > out/test_spark_q1.out 2>&1
if grep -E -q "Seq\[String\] = List\([0-9\.:]*, [0-9\.:]*, [0-9\.:]*\)" out/test_spark_q1.out; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    print_score "0 point"
    exit 1
fi

echo -n "Testing Spark Q2 ..."
test_spark_q2 > out/test_spark_q2.out 2>&1
if grep -E -q '^Pi is roughly 3.14[0-9]*' out/test_spark_q2.out; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    print_score "10 points"
    exit 1
fi

echo -n "Testing Spark Q3 ..."
test_spark_q3 > out/test_spark_q3.out 2>&1
if grep -q 'Array(The quick brown fox jumps over the lazy dog)' out/test_spark_q3.out; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    print_score "20 points"
    exit 1
fi

echo -n "Testing Spark Q4 ..."
test_spark_q4 > out/test_spark_q4.out 2>&1
if grep -E -q "^Number of records written: 1000000[[:space:]]*$" out/test_spark_q4.out && \
   grep -q "==== TeraSort took .* ====" out/test_spark_q4.out && \
   grep -q "7a30469d6f066" out/test_spark_q4.out && \
   grep -q "partitions are properly sorted" out/test_spark_q4.out; then
    echo -e " ${GREEN}PASS${NC}"
else
    echo -e " ${RED}FAIL${NC}"
    print_score "30 points"
    exit 1
fi

print_score "40 points (full score)"
