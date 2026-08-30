from pathlib import Path

import paramiko


PRIVATE_KEY = Path(__file__).with_name("eldercare_deploy_rsa")
PUBLIC_KEY = Path(__file__).with_name("eldercare_deploy_rsa.pub")


def main() -> int:
    if PRIVATE_KEY.exists() or PUBLIC_KEY.exists():
        raise FileExistsError("Task key path already exists")
    key = paramiko.RSAKey.generate(bits=3072)
    key.write_private_key_file(str(PRIVATE_KEY))
    PUBLIC_KEY.write_text(
        f"{key.get_name()} {key.get_base64()} codex-eldercare-20260820-v2\n",
        encoding="utf-8",
    )
    print("TASK_KEY_CREATED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
