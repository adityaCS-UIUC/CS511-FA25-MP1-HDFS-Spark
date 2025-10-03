#!/bin/bash
docker build -t cs511p1-common -f cs511p1-common.Dockerfile . && \
docker build -t cs511p1-main   -f cs511p1-main.Dockerfile   . && \
docker build -t cs511p1-worker -f cs511p1-worker.Dockerfile . && \
docker compose -f cs511p1-compose.yaml -f docker-compose.spark.yml up -d

# start Spark master & workers (official image paths)
docker compose -f cs511p1-compose.yaml -f docker-compose.spark.yml exec -T main    bash -lc '/opt/spark/sbin/start-master.sh -p 7077'
docker compose -f cs511p1-compose.yaml -f docker-compose.spark.yml exec -T worker1 bash -lc '/opt/spark/sbin/start-worker.sh spark://main:7077'
docker compose -f cs511p1-compose.yaml -f docker-compose.spark.yml exec -T worker2 bash -lc '/opt/spark/sbin/start-worker.sh spark://main:7077'