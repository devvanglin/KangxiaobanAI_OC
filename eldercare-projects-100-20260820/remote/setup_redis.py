from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path("/opt/eldercare100")
SECRETS_PATH = ROOT / "private" / "secrets.json"
IMAGE = "ec100/redis:7-alpine"
CONTAINER = "ec100-redis"


def run(command: list[str], timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def main() -> int:
    secrets = json.loads(SECRETS_PATH.read_text(encoding="utf-8"))
    password = secrets["redis_password"]
    inspect = run(["docker", "image", "inspect", IMAGE], timeout=30)
    if inspect.returncode != 0:
        context = ROOT / "infra" / "redis"
        context.mkdir(parents=True, exist_ok=True)
        dockerfile = context / "Dockerfile"
        dockerfile.write_text(
            "FROM node:18-alpine\n"
            "RUN apk add --no-cache redis\n"
            "ENTRYPOINT [\"redis-server\"]\n",
            encoding="utf-8",
        )
        built = run(["docker", "build", "-t", IMAGE, str(context)], timeout=900)
        if built.returncode != 0:
            print(built.stdout[-4000:])
            return 2
    run(["docker", "rm", "-f", CONTAINER], timeout=60)
    started = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            CONTAINER,
            "--network",
            "ec100_net",
            "--memory",
            "192m",
            "--cpus",
            "0.20",
            "--restart",
            "unless-stopped",
            "--label",
            "com.kxb.task=eldercare100",
            IMAGE,
            "--appendonly",
            "yes",
            "--requirepass",
            password,
        ],
        timeout=60,
    )
    if started.returncode != 0:
        print(started.stdout[-2000:])
        return 2
    ready = run(
        ["docker", "exec", CONTAINER, "redis-cli", "-a", password, "PING"],
        timeout=30,
    )
    if ready.returncode != 0 or "PONG" not in ready.stdout:
        print("Redis did not become ready")
        return 2
    print("REDIS_READY container=ec100-redis network=ec100_net memory=192m cpu=0.20")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
