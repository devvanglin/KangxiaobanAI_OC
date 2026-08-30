#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/eldercare100
TASK_USER=node2
TASK_GROUP=node2

install -d -m 0750 "$ROOT"
install -d -m 0750 \
  "$ROOT/sources" "$ROOT/apps" "$ROOT/state" "$ROOT/logs" "$ROOT/cache" "$ROOT/private" "$ROOT/tools" "$ROOT/infra"
install -d -m 0750 \
  "$ROOT/cache/maven" "$ROOT/cache/npm" "$ROOT/cache/gradle" "$ROOT/cache/pip"

if [[ ! -f "$ROOT/private/secrets.json" ]]; then
  echo "missing $ROOT/private/secrets.json" >&2
  exit 2
fi
chmod 0600 "$ROOT/private/secrets.json"

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
    --memory 1800m \
    --cpus 2.0 \
    --env-file "$ROOT/private/infra.env" \
    --label com.kxb.task=eldercare100 \
    --health-cmd='mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=30 \
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
    --memory 900m \
    --cpus 1.0 \
    --env-file "$ROOT/private/infra.env" \
    --label com.kxb.task=eldercare100 \
    --health-cmd='pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=30 \
    -v ec100_postgres_data:/var/lib/postgresql/data \
    postgres:16-alpine >/dev/null
fi

python3 "$ROOT/tools/setup_redis.py"

for name in ec100-mysql ec100-postgres ec100-redis; do
  for _ in $(seq 1 60); do
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
