#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/eldercare100
TASK_USER=pve
TASK_GROUP=pve

sudo install -d -m 0750 -o "$TASK_USER" -g "$TASK_GROUP" "$ROOT"
sudo install -d -m 0750 -o "$TASK_USER" -g "$TASK_GROUP" \
  "$ROOT/sources" "$ROOT/apps" "$ROOT/state" "$ROOT/logs" "$ROOT/cache" "$ROOT/private"
sudo install -d -m 0750 -o "$TASK_USER" -g "$TASK_GROUP" \
  "$ROOT/cache/maven" "$ROOT/cache/npm" "$ROOT/cache/gradle" "$ROOT/cache/pip"

if [[ ! -f /tmp/ec100-secrets.json ]]; then
  echo "missing /tmp/ec100-secrets.json" >&2
  exit 2
fi
sudo install -m 0600 -o "$TASK_USER" -g "$TASK_GROUP" /tmp/ec100-secrets.json "$ROOT/private/secrets.json"
rm -f /tmp/ec100-secrets.json

python3 - "$ROOT/private/secrets.json" "$ROOT/private/infra.env" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
lines = [
    f"MYSQL_ROOT_PASSWORD={data['mysql_root_password']}",
    f"MYSQL_USER={data['mysql_app_user']}",
    f"MYSQL_PASSWORD={data['mysql_app_password']}",
    "MYSQL_DATABASE=eldercare_registry",
    f"POSTGRES_USER={data['postgres_superuser']}",
    f"POSTGRES_PASSWORD={data['postgres_password']}",
    "POSTGRES_DB=eldercare_registry",
]
target.write_text("\n".join(lines) + "\n", encoding="utf-8")
target.chmod(0o600)
PY

if ! docker network inspect ec100_net >/dev/null 2>&1; then
  docker network create --label com.kxb.task=eldercare100 ec100_net >/dev/null
fi

if ! docker container inspect ec100-mysql >/dev/null 2>&1; then
  docker run -d \
    --name ec100-mysql \
    --network ec100_net \
    --restart unless-stopped \
    --memory 1400m \
    --cpus 1.0 \
    --env-file "$ROOT/private/infra.env" \
    --label com.kxb.task=eldercare100 \
    --health-cmd='mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=20 \
    -v ec100_mysql_data:/var/lib/mysql \
    mysql:8.0 \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci >/dev/null
fi

if ! docker container inspect ec100-postgres >/dev/null 2>&1; then
  docker run -d \
    --name ec100-postgres \
    --network ec100_net \
    --restart unless-stopped \
    --memory 700m \
    --cpus 0.5 \
    --env-file "$ROOT/private/infra.env" \
    --label com.kxb.task=eldercare100 \
    --health-cmd='pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=20 \
    -v ec100_postgres_data:/var/lib/postgresql/data \
    postgres:16-alpine >/dev/null
fi

REDIS_PASSWORD=$(python3 -c 'import json; print(json.load(open("/opt/eldercare100/private/secrets.json"))["redis_password"])')
if ! docker container inspect ec100-redis >/dev/null 2>&1; then
  docker run -d \
    --name ec100-redis \
    --network ec100_net \
    --restart unless-stopped \
    --memory 160m \
    --cpus 0.2 \
    --label com.kxb.task=eldercare100 \
    --health-cmd="redis-cli -a '$REDIS_PASSWORD' ping | grep PONG" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=20 \
    -v ec100_redis_data:/data \
    redis:7-alpine redis-server --appendonly yes --requirepass "$REDIS_PASSWORD" >/dev/null
fi

for name in ec100-mysql ec100-postgres ec100-redis; do
  for _ in $(seq 1 30); do
    status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name")
    if [[ "$status" == healthy || "$status" == running ]]; then
      break
    fi
    sleep 2
  done
  status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name")
  printf '%s=%s\n' "$name" "$status"
  if [[ "$status" != healthy && "$status" != running ]]; then
    docker logs --tail 80 "$name" >&2
    exit 3
  fi
done

docker ps --filter label=com.kxb.task=eldercare100 \
  --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}'
