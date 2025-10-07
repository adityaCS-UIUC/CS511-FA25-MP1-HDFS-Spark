docker build -t cs511p1-common -f cs511p1-common.Dockerfile . >/dev/null 2>&1
docker build -t cs511p1-main   -f cs511p1-main.Dockerfile   . >/dev/null 2>&1
docker build -t cs511p1-worker -f cs511p1-worker.Dockerfile . >/dev/null 2>&1
docker compose -f cs511p1-compose.yaml up -d >/dev/null 2>&1