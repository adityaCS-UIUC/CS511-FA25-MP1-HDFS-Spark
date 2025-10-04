#!/bin/bash

# backup
function test_spark_q1() {
  # Run entirely INSIDE the container so Docker DNS works.
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -euo pipefail

    # 1) Warm executors so they register with the master
    /opt/spark/bin/spark-shell --master spark://main:7077 -e "sc.parallelize(1 to 1000,3).count" >/dev/null 2>&1 || true

    # 2) Get executor endpoints (host:port), strip ports -> host tokens
    HOSTS=$(/opt/spark/bin/spark-shell --master spark://main:7077 -e "sc.getExecutorMemoryStatus.keys.foreach(println)" 2>/dev/null \
            | awk -F: "NF{print \$1}" | sort -u)

    # 3) Build name<->IP maps for main/worker1/worker2 from container DNS
    declare -A NAME2IP IP2NAME
    for n in main worker1 worker2; do
      ip=$(getent hosts "$n" | awk "{print \$1}" || true)
      [ -n "$ip" ] && NAME2IP[$n]="$ip" && IP2NAME[$ip]="$n"
    done

    # 4) Driver host (normalize to name if it was an IP)
    RAWDRV=$(/opt/spark/bin/spark-shell --master spark://main:7077 -e "println(sc.getConf.get(\"spark.driver.host\"))" 2>/dev/null | tail -n1 || true)
    DRV=${IP2NAME[$RAWDRV]:-$RAWDRV}

    # 5) Map each host token (IP or name) -> canonical name, drop driver, keep only worker1/worker2
    OUT=""
    while read -r H; do
      [ -z "$H" ] && continue
      if [[ -n "${IP2NAME[$H]:-}" ]]; then
        N="${IP2NAME[$H]}"
      else
        # If H is already a hostname, keep it; if it resolves to a known IP, map that back to the name
        ip=$(getent hosts "$H" | awk "{print \$1}" || true)
        if [[ -n "$ip" && -n "${IP2NAME[$ip]:-}" ]]; then
          N="${IP2NAME[$ip]}"
        else
          N="$H"
        fi
      fi
      [[ "$N" == "$DRV" ]] && continue
      [[ "$N" == "worker1" || "$N" == "worker2" ]] && OUT+="$N"$'\n'
    done <<< "$HOSTS"

    # 6) Emit exactly the two lines (sorted unique)
    echo "$OUT" | grep -E "worker[12]" | sort -u
  ' > out/test_spark_q1.out 2>&1

  # Show what got captured (useful for debugging if needed)
  cat out/test_spark_q1.out
}

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
