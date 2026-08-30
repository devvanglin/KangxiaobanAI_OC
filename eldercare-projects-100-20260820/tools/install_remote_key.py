from __future__ import annotations

import getpass
from pathlib import Path

import paramiko


HOST = "192.168.100.104"
PORT = 22
USER = "pve"
PUBLIC_KEY = Path(__file__).with_name("eldercare_deploy_rsa.pub")


def main() -> int:
    public_key = PUBLIC_KEY.read_text(encoding="utf-8").strip()
    if not public_key.startswith(("ssh-ed25519 ", "ssh-rsa ")):
        raise RuntimeError("Unexpected public key format")
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
    )
    sftp = client.open_sftp()
    try:
        sftp.stat(".ssh")
    except OSError:
        sftp.mkdir(".ssh", mode=0o700)
    try:
        with sftp.open(".ssh/authorized_keys", "r") as handle:
            existing = handle.read().decode("utf-8", "replace")
    except OSError:
        existing = ""
    if public_key not in existing.splitlines():
        with sftp.open(".ssh/authorized_keys", "a") as handle:
            if existing and not existing.endswith("\n"):
                handle.write("\n")
            handle.write(public_key + "\n")
    sftp.chmod(".ssh", 0o700)
    sftp.chmod(".ssh/authorized_keys", 0o600)
    sftp.close()
    client.close()
    print("TASK_KEY_INSTALLED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
