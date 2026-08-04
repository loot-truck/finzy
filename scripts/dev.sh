#!/usr/bin/env bash
# Bring the stack up and wait until it answers.
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose up --build -d

echo "waiting for the gateway..."
for _ in $(seq 1 60); do
  if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
    echo "stack is up: http://localhost:8080"
    exit 0
  fi
  sleep 2
done

echo "gateway did not become healthy; recent logs:" >&2
docker compose logs --tail=50 gateway nginx >&2
exit 1
