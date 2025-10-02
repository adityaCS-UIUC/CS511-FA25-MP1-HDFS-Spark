#!/bin/bash
set -euo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; NC="\033[0m"
mkdir -p out

function test_terasorting() {
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -euo pipefail
    mkdir -p /tmp/caps
    cat > /tmp/caps/caps.csv <<EOF
1999,1234-5678-91011
1800,1001-1002-10003
2023,0829-0914-00120
2050,9999-9999-99999
EOF
    /opt/hadoop/bin/hdfs dfs -mkdir -p /datasets
    /opt/hadoop/bin/hdfs dfs -put -f /tmp/caps/caps.csv /datasets/caps.csv
    spark-shell --master spark://main:7077 -i /apps/terasorting.scala 2>/dev/null | grep -E "^[0-9]{4},"
  '
}

function test_pagerank() {
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -euo pipefail
    mkdir -p /tmp/pr
    cat > /tmp/pr/pagerank_edges.csv <<EOF
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
    /opt/hadoop/bin/hdfs dfs -mkdir -p /datasets
    /opt/hadoop/bin/hdfs dfs -put -f /tmp/pr/pagerank_edges.csv /datasets/pagerank_edges.csv
    spark-shell --master spark://main:7077 -i /apps/pagerank.scala 2>/dev/null | grep -E "^[0-9]+,"
  '
}

total_score=0

echo -n "Testing Tera Sorting ..."
test_terasorting > out/test_terasorting.out 2>&1 || true
if [ -f resources/example-terasorting.truth ] && diff --strip-trailing-cr resources/example-terasorting.truth out/test_terasorting.out; then
  echo -e " ${GREEN}PASS${NC}"; (( total_score+=20 ));
else
  if [ ! -f resources/example-terasorting.truth ]; then echo; echo "NOTE: truth file missing; showing output:"; cat out/test_terasorting.out; fi
  echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing PageRank (extra credit) ..."
test_pagerank > out/test_pagerank.out 2>&1 || true
if [ -f resources/example-pagerank.truth ] && diff --strip-trailing-cr resources/example-pagerank.truth out/test_pagerank.out; then
  echo -e " ${GREEN}PASS${NC}"; (( total_score+=20 ));
else
  if [ ! -f resources/example-pagerank.truth ]; then echo; echo "NOTE: truth file missing; showing output:"; cat out/test_pagerank.out; fi
  echo -e " ${RED}FAIL${NC}"
fi

echo "-----------------------------------"
echo "Result: $total_score point(s)"
