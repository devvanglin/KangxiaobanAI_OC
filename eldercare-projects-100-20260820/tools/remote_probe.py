from __future__ import annotations

import getpass
import hashlib
import json
import sys

import paramiko


HOST = "192.168.100.104"
PORT = 22
USER = "pve"


def run(client: paramiko.SSHClient, command: str, password: str | None = None) -> dict[str, object]:
    stdin, stdout, stderr = client.exec_command(command, timeout=30)
    if password is not None:
        stdin.write(password + "\n")
        stdin.flush()
    exit_code = stdout.channel.recv_exit_status()
    return {
        "command": command.replace("sudo -S -p ''", "sudo"),
        "exit_code": exit_code,
        "stdout": stdout.read().decode("utf-8", "replace").strip(),
        "stderr": stderr.read().decode("utf-8", "replace").strip(),
    }


def main() -> int:
    password = getpass.getpass("SSH password: ")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        HOST,
        port=PORT,
        username=USER,
        password=password,
        look_for_keys=False,
        allow_agent=False,
        timeout=15,
        banner_timeout=15,
        auth_timeout=15,
    )
    transport = client.get_transport()
    if transport is None:
        raise RuntimeError("SSH transport unavailable")
    key = transport.get_remote_server_key().asbytes()
    result = {
        "host": HOST,
        "port": PORT,
        "user": USER,
        "host_key_sha256": hashlib.sha256(key).hexdigest(),
        "checks": [
            run(client, "id"),
            run(client, "uname -a"),
            run(client, "cat /etc/os-release"),
            run(client, "nproc"),
            run(client, "free -m"),
            run(client, "df -h /"),
            run(client, "sudo -S -p '' true", password),
            run(client, "sudo -S -p '' docker version --format '{{json .Server}}'", password),
            run(client, "sudo -S -p '' docker compose version", password),
            run(client, "sudo -S -p '' docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}'", password),
            run(client, "sudo -S -p '' ss -ltn", password),
        ],
    }
    client.close()
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
