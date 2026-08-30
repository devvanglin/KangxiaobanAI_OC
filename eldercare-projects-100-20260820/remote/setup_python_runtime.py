from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path("/opt/eldercare100")
IMAGE = "ec100/python-runtime:3"


def run(command: list[str], timeout: int = 1800) -> subprocess.CompletedProcess[str]:
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
    if run(["docker", "image", "inspect", IMAGE], timeout=30).returncode == 0:
        print("PYTHON_RUNTIME_READY cached=true")
        return 0
    context = ROOT / "infra" / "python-runtime"
    context.mkdir(parents=True, exist_ok=True)
    dockerfile = """FROM maven:3.9-eclipse-temurin-17
RUN apt-get update \\
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 python3-pip python3-venv gcc g++ \\
 && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /venv \\
 && /venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \\
 && /venv/bin/pip install --no-cache-dir Flask Flask-CORS python-dotenv gunicorn pandas numpy joblib scikit-learn xgboost Faker xlsxwriter happybase pyhive thrift thrift-sasl
ENV PATH=/venv/bin:$PATH PYTHONUNBUFFERED=1
WORKDIR /app
"""
    (context / "Dockerfile").write_text(dockerfile, encoding="utf-8")
    built = run(["docker", "build", "-t", IMAGE, str(context)], timeout=2400)
    if built.returncode != 0:
        print(built.stdout[-6000:])
        return 2
    check = run(
        [
            "docker",
            "run",
            "--rm",
            IMAGE,
            "python",
            "-c",
            "import flask,pandas,numpy,sklearn,xgboost; print('PYTHON_IMPORTS_OK')",
        ],
        timeout=120,
    )
    if check.returncode != 0 or "PYTHON_IMPORTS_OK" not in check.stdout:
        print(check.stdout[-3000:])
        return 2
    print("PYTHON_RUNTIME_READY cached=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
