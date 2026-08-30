from __future__ import annotations

import json
import secrets
import string
from pathlib import Path


TASK_ROOT = Path(__file__).resolve().parents[1]
OUTPUT = TASK_ROOT / "manifests" / "private" / "server-secrets.json"


def token(length: int = 28) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main() -> int:
    if OUTPUT.exists():
        data = json.loads(OUTPUT.read_text(encoding="utf-8"))
        changed = False
        if "redis_password" not in data:
            data["redis_password"] = token(32)
            changed = True
        if changed:
            OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            print("SECRETS_EXTENDED")
        else:
            print("SECRETS_ALREADY_EXIST")
        return 0
    data = {
        "mysql_root_password": token(32),
        "mysql_app_user": "eldercare",
        "mysql_app_password": token(32),
        "postgres_superuser": "eldercare",
        "postgres_password": token(32),
        "redis_password": token(32),
        "portal_username": "admin",
        "portal_password": token(24),
        "preferred_application_admin_username": "admin",
        "preferred_application_admin_password": token(20),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print("SECRETS_CREATED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
