#!/bin/bash
set -euo pipefail
docker compose -f cs511p1-compose.yaml build --no-cache
docker compose -f cs511p1-compose.yaml up -d
sleep 2
docker compose -f cs511p1-compose.yaml ps
