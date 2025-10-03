#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
mkdir -p out
total_score=0

# --- HDFS block ---
echo -n "Testing HDFS Q1 ..."
docker compose -f cs511p1-compose.yaml exec main hdfs dfsadmin -report > out/test_hdfs_q1.out 2>&1 || true
if grep -q "Live datanodes (3)" out/test_hdfs_q1.out; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q2 ..."
docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
if docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -mkdir -p /test && hdfs dfs -put -f /test_fox.txt /test/fox.txt && hdfs dfs -cat /test/fox.txt' > out/test_hdfs_q2.out 2>&1 \
   && grep -q 'The quick brown fox' out/test_hdfs_q2.out; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q3 ..."
if docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op create -threads 10 -files 1000 >/dev/null && \
  hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op open   -threads 10 -files 1000 >/dev/null && \
  hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op delete -threads 10 -files 1000 >/dev/null && \
  hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op rename -threads 10 -files 1000 >/dev/null' > out/test_hdfs_q3.out 2>&1; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q4 ..."
docker compose -f cs511p1-compose.yaml cp resources/hadoop-terasort-3.3.6.jar main:/hadoop-terasort-3.3.6.jar
if docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -rm -r -f tera-in tera-out tera-val >/dev/null 2>&1 || true; \
  hadoop jar /hadoop-terasort-3.3.6.jar teragen 100000 tera-in && \
  hadoop jar /hadoop-terasort-3.3.6.jar terasort tera-in tera-out && \
  hadoop jar /hadoop-terasort-3.3.6.jar teravalidate tera-out tera-val' > out/test_hdfs_q4.out 2>&1; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

# --- Spark block ---
echo -n "Testing Spark Q1 ..."
docker compose -f cs511p1-compose.yaml cp resources/active_executors.scala main:/active_executors.scala
if docker compose -f cs511p1-compose.yaml exec main bash -c 'cat /active_executors.scala | spark-shell --master spark://main:7077' \
   > out/test_spark_q1.out 2>&1 && \
   grep -q "worker1" out/test_spark_q1.out && grep -q "worker2" out/test_spark_q1.out; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q2 ..."
docker compose -f cs511p1-compose.yaml cp resources/pi.scala main:/pi.scala
if docker compose -f cs511p1-compose.yaml exec main bash -c 'cat /pi.scala | spark-shell --master spark://main:7077' \
   > out/test_spark_q2.out 2>&1 && grep -q "Pi is roughly" out/test_spark_q2.out; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q3 ..."
docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
if docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -mkdir -p /test && hdfs dfs -put -f /test_fox.txt /test/fox.txt && \
  echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | spark-shell --master spark://main:7077' \
   > out/test_spark_q3.out 2>&1 && \
   grep -q 'Array(The quick brown fox jumps over the lazy dog)' out/test_spark_q3.out; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q4 ..."
docker compose -f cs511p1-compose.yaml cp resources/spark-terasort-1.2.jar main:/spark-terasort-1.2.jar
if docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -rm -r -f /spark/tera-in /spark/tera-out /spark/tera-val >/dev/null 2>&1 || true; \
  spark-submit --master spark://main:7077 \
    --class com.github.ehiggs.spark.terasort.TeraGen /spark-terasort-1.2.jar 50m hdfs://main:9000/spark/tera-in && \
  spark-submit --master spark://main:7077 \
    --class com.github.ehiggs.spark.terasort.TeraSort /spark-terasort-1.2.jar \
    hdfs://main:9000/spark/tera-in hdfs://main:9000/spark/tera-out && \
  spark-submit --master spark://main:7077 \
    --class com.github.ehiggs.spark.terasort.TeraValidate /spark-terasort-1.2.jar \
    hdfs://main:9000/spark/tera-out hdfs://main:9000/spark/tera-val' \
   > out/test_spark_q4.out 2>&1; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+10))
else
  echo -e " ${RED}FAIL${NC}"
fi

# --- Part 3: TeraSorting demo ---
echo -n "Testing Tera Sorting ..."
# Create a small CSV (including a future year which must be dropped)
cat > /tmp/caps.csv <<EOF
2023,0829-0914-00120
1999,1234-5678-91011
1800,1001-1002-10003
2050,9999-9999-99999
EOF
docker compose -f cs511p1-compose.yaml cp /tmp/caps.csv main:/caps.csv

# Run a tiny Scala job that produces the sorted result to stdout
docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -rm -f /data/caps.csv >/dev/null 2>&1 || true; \
  hdfs dfs -mkdir -p /data && hdfs dfs -put -f /caps.csv /data/caps.csv && \
  cat <<\"SCALA\" | spark-shell --master spark://main:7077
val rdd = sc.textFile(\"hdfs://main:9000/data/caps.csv\")
val out = rdd.map(_.trim).filter(_.nonEmpty)
  .map{ s => val p=s.split(\",\"); (p(0).toInt, p(1)) }
  .filter{ case (year,_) => year <= 2025 }
  .sortBy({ case (y,sn) => (-y, sn) }, ascending=true)
  .map{ case (y,sn) => s\"$y,$sn\" }
out.collect().foreach(println)
SCALA' > out/test_terasorting.out 2>&1 || true

if diff --strip-trailing-cr resources/example-terasorting.truth out/test_terasorting.out >/dev/null 2>&1; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+20))
else
  echo -e " ${RED}FAIL${NC}"
fi

# --- Part 4: PageRank (extra credit) ---
echo -n "Testing PageRank (extra credit) ..."
cat > /tmp/edges.csv <<EOF
2,3
3,2
4,2
5,2
5,6
6,5
7,5
8,5
9,5
10,5
11,5
4,1
EOF
docker compose -f cs511p1-compose.yaml cp /tmp/edges.csv main:/edges.csv

docker compose -f cs511p1-compose.yaml exec main bash -c '\
  hdfs dfs -rm -f /graph/edges.csv >/dev/null 2>&1 || true; \
  hdfs dfs -mkdir -p /graph && hdfs dfs -put -f /edges.csv /graph/edges.csv && \
  cat <<\"SCALA\" | spark-shell --master spark://main:7077
val d = 0.85
val eps = 1e-4
val edges = sc.textFile(\"hdfs://main:9000/graph/edges.csv\").map(_.trim).filter(_.nonEmpty)
  .map{ line => val p=line.split(\",\"); (p(0).toInt, p(1).toInt) }
val nodes = edges.flatMap{ case (s,t) => Seq(s,t) }.distinct().cache()
val N = nodes.count().toDouble
val links = edges.groupByKey().mapValues(_.toSet).cache()
var ranks = nodes.map(n => (n, 1.0/N)).cache()
def iterate(r: org.apache.spark.rdd.RDD[(Int,Double)]) = {
  val contribs = links.leftOuterJoin(r).flatMap{ case (n,(outs,rankOpt)) =>
    val rank = rankOpt.getOrElse(0.0)
    if (outs.isEmpty) Seq() else outs.toSeq.map(dst => (dst, rank/outs.size))
  }
  val newRanks = contribs.reduceByKey(_ + _).rightOuterJoin(nodes.map((_,()))).map{
    case (n,(sumOpt,_)) => (n, (1-d)/N + d*sumOpt.getOrElse(0.0))
  }
  newRanks
}
var delta = Double.MaxValue
var i = 0
while (delta > eps && i < 50) {
  val newRanks = iterate(ranks).cache()
  val joined = ranks.join(newRanks).map{ case (_, (a,b)) => math.abs(a-b) }
  delta = joined.max()
  ranks.unpersist(false); ranks = newRanks; i += 1
}
val fmt = java.text.DecimalFormat(\"0.000\")
val out = ranks.map{ case (n,r) => (n, r) }.collect().toSeq
  .sortBy{ case (n,r) => (-r, n) }
out.foreach{ case (n,r) => println(s\"$n,${fmt.format(r)}\") }
SCALA' > out/test_pagerank.out 2>&1 || true

if diff --strip-trailing-cr resources/example-pagerank.truth out/test_pagerank.out >/dev/null 2>&1; then
  echo -e " ${GREEN}PASS${NC}"; total_score=$((total_score+20))
else
  echo -e " ${RED}FAIL${NC}"
fi

echo "-----------------------------------"
echo "Total Points/Full Points: ${total_score}/120"
