from __future__ import annotations

import argparse
import base64
import hashlib
import http.cookiejar
import hmac
import io
import json
import os
import re
import struct
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
PLAN_PATH = ROOT / "state" / "build-plan.json"
BUILD_RESULTS = ROOT / "state" / "build-results.json"
RUNTIME_RESULTS = ROOT / "state" / "runtime-results.json"
LOGIN_RESULTS = ROOT / "private" / "login-results.json"
SECRETS_PATH = ROOT / "private" / "secrets.json"
GATEWAY = ROOT / "static_gateway.js"
EMBEDDING_STUB = ROOT / "tools" / "embedding_stub.py"
PUBLIC_HOST = os.environ.get("ELDERCARE_PUBLIC_HOST", "127.0.0.1")


def run(command: list[str], timeout: int = 180) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def load_results(path: Path) -> dict[str, dict[str, Any]]:
    if not path.is_file():
        return {}
    try:
        return {item["id"]: item for item in json.loads(path.read_text(encoding="utf-8"))}
    except (OSError, json.JSONDecodeError, KeyError):
        return {}


def save_results(path: Path, results: dict[str, dict[str, Any]], private: bool = False) -> None:
    payload = json.dumps([results[key] for key in sorted(results)], ensure_ascii=False, indent=2)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(payload, encoding="utf-8")
    os.replace(temporary, path)
    if private:
        path.chmod(0o600)


def http_request(
    url: str,
    method: str = "GET",
    data: dict[str, Any] | None = None,
    timeout: int = 10,
    headers: dict[str, str] | None = None,
) -> dict[str, Any]:
    payload = json.dumps(data, ensure_ascii=False).encode("utf-8") if data is not None else None
    request = urllib.request.Request(
        url,
        data=payload,
        method=method,
        headers={
            "content-type": "application/json",
            "accept": "application/json, text/plain, */*",
            **(headers or {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8", "replace")
            return {"http_status": response.status, "body": body[:65536], "error": ""}
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", "replace")
        return {"http_status": error.code, "body": body[:65536], "error": ""}
    except (OSError, urllib.error.URLError) as error:
        return {"http_status": 0, "body": "", "error": str(error)}


def opener_request(
    opener: urllib.request.OpenerDirector,
    url: str,
    method: str = "GET",
    data: dict[str, Any] | None = None,
    timeout: int = 10,
) -> dict[str, Any]:
    payload = json.dumps(data, ensure_ascii=False).encode("utf-8") if data is not None else None
    request = urllib.request.Request(
        url,
        data=payload,
        method=method,
        headers={"content-type": "application/json", "accept": "application/json"},
    )
    try:
        with opener.open(request, timeout=timeout) as response:
            return {
                "http_status": response.status,
                "body": response.read().decode("utf-8", "replace")[:65536],
                "error": "",
            }
    except urllib.error.HTTPError as error:
        return {
            "http_status": error.code,
            "body": error.read().decode("utf-8", "replace")[:65536],
            "error": "",
        }
    except (OSError, urllib.error.URLError) as error:
        return {"http_status": 0, "body": "", "error": str(error)}


def opener_form_request(
    opener: urllib.request.OpenerDirector,
    url: str,
    data: dict[str, str],
    timeout: int = 10,
) -> dict[str, Any]:
    payload = urllib.parse.urlencode(data).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "content-type": "application/x-www-form-urlencoded",
            "accept": "application/json, text/plain, */*",
        },
    )
    try:
        with opener.open(request, timeout=timeout) as response:
            return {
                "http_status": response.status,
                "body": response.read().decode("utf-8", "replace")[:65536],
                "error": "",
            }
    except urllib.error.HTTPError as error:
        return {
            "http_status": error.code,
            "body": error.read().decode("utf-8", "replace")[:65536],
            "error": "",
        }
    except (OSError, urllib.error.URLError) as error:
        return {"http_status": 0, "body": "", "error": str(error)}


def form_request(url: str, data: dict[str, str], timeout: int = 10) -> dict[str, Any]:
    payload = urllib.parse.urlencode(data).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "content-type": "application/x-www-form-urlencoded",
            "accept": "application/json, text/plain, */*",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return {
                "http_status": response.status,
                "body": response.read().decode("utf-8", "replace")[:65536],
                "error": "",
            }
    except urllib.error.HTTPError as error:
        return {
            "http_status": error.code,
            "body": error.read().decode("utf-8", "replace")[:65536],
            "error": "",
        }
    except (OSError, urllib.error.URLError) as error:
        return {"http_status": 0, "body": "", "error": str(error)}


def totp_code(secret: str, timestamp: int | None = None) -> str:
    normalized = re.sub(r"\s+", "", secret).upper()
    normalized += "=" * ((8 - len(normalized) % 8) % 8)
    key = base64.b32decode(normalized, casefold=True)
    counter = int(timestamp if timestamp is not None else time.time()) // 30
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return f"{value % 1_000_000:06d}"


def wait_http(url: str, seconds: int = 120) -> dict[str, Any]:
    deadline = time.monotonic() + seconds
    last = {"http_status": 0, "body": "", "error": "not attempted"}
    while time.monotonic() < deadline:
        last = http_request(url, timeout=5)
        if last["http_status"]:
            return last
        time.sleep(3)
    return last


def wait_entry(base_url: str, seconds: int = 180, api_container: str = "") -> dict[str, Any]:
    paths = (
        "",
        "login",
        "login.html",
        "admin/login",
        "index.html",
        "docs",
        "health",
        "doc.html",
        "swagger-ui/index.html",
        "swagger-ui.html",
        "api/orders/all",
        "api/ping",
        "api/stats",
        "api/health",
        "api/v1/users",
        "about",
        "v1/patients",
        "captcha/getCode",
        "test/demo1",
        "test",
        "yanglaoyuanguanli/",
        "yanglaoyuanguanli/doc.html",
        "yanglaoyuanguanli/config/list",
        "sqlrjkxxglxt/",
        "sqlrjkxxglxt/doc.html",
        "sqlrjkxxglxt/config/list",
        "zhihuishequjujiayanglaojiankang/config/list",
        "springboot35806/",
        "springboot35806/doc.html",
        "springboot35806/config/list",
        "springboot1w568/",
        "springboot1w568/doc.html",
        "springboot1w568/config/list",
        "springboot1816sl21/config/list",
        "springbootu1yrv/",
        "springbootu1yrv/doc.html",
        "springbootu1yrv/swagger-ui.html",
        "springbootu1yrv/config/list",
    )
    deadline = time.monotonic() + seconds
    last = {"http_status": 0, "body": "", "error": "not attempted", "path": ""}
    while time.monotonic() < deadline:
        for path in paths:
            result = http_request(base_url.rstrip("/") + "/" + path, timeout=5)
            result["path"] = "/" + path
            last = result
            if result["http_status"] == 200:
                return result
        if base_url.rstrip("/").endswith(":18080"):
            result = http_request(
                base_url.rstrip("/") + "/api/auth/login",
                method="POST",
                data={"username": "admin", "password": "Admin@123"},
                timeout=8,
            )
            result["path"] = "/api/auth/login"
            last = result
            if result["http_status"] == 200:
                return result
        if api_container:
            state = run(["docker", "inspect", "--format", "{{.State.Running}}", api_container], timeout=10)
            if state.returncode != 0 or state.stdout.strip().lower() != "true":
                last["error"] = f"API container exited: {api_container}"
                return last
        time.sleep(2)
    return last


def parse_json_response(response: dict[str, Any]) -> dict[str, Any] | None:
    try:
        value = json.loads(response.get("body", ""))
    except (TypeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def write_private_env_file(project_id: str, suffix: str, values: dict[str, str]) -> Path:
    private_dir = ROOT / "private" / "apps"
    private_dir.mkdir(parents=True, exist_ok=True)
    path = private_dir / f"{project_id}-{suffix}.env"
    path.write_text("\n".join(f"{key}={value}" for key, value in values.items()) + "\n", encoding="utf-8")
    path.chmod(0o600)
    return path


def wait_api_response(
    url: str,
    method: str,
    data: dict[str, Any],
    seconds: int = 180,
) -> dict[str, Any]:
    """Wait until the application API responds, not merely the static gateway."""
    deadline = time.monotonic() + seconds
    last = {"http_status": 0, "body": "", "error": "not attempted"}
    while time.monotonic() < deadline:
        last = http_request(url, method=method, data=data, timeout=8)
        parsed = parse_json_response(last)
        if (
            last["http_status"] not in (0, 502, 503, 504)
            and parsed is not None
            and parsed.get("code") not in (502, 503, 504)
        ):
            return last
        time.sleep(3)
    return last


def write_env(plan: dict[str, Any], secrets: dict[str, str]) -> Path:
    private_dir = ROOT / "private" / "apps"
    private_dir.mkdir(parents=True, exist_ok=True)
    path = private_dir / f"{plan['id']}.env"
    database_url = (
        f"jdbc:mysql://ec100-mysql:3306/{plan['database_name']}?"
        "useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&"
        "useSSL=false&allowPublicKeyRetrieval=true"
    )
    values = {
        "SERVER_PORT": "8080",
        "SPRING_DATASOURCE_URL": database_url,
        "SPRING_DATASOURCE_USERNAME": "root",
        "SPRING_DATASOURCE_PASSWORD": secrets["mysql_root_password"],
        "SPRING_DATASOURCE_DRUID_URL": database_url,
        "SPRING_DATASOURCE_DRUID_USERNAME": "root",
        "SPRING_DATASOURCE_DRUID_PASSWORD": secrets["mysql_root_password"],
        "SPRING_DATASOURCE_DRUID_MASTER_URL": database_url,
        "SPRING_DATASOURCE_DRUID_MASTER_USERNAME": "root",
        "SPRING_DATASOURCE_DRUID_MASTER_PASSWORD": secrets["mysql_root_password"],
        "SPRING_DATA_REDIS_HOST": "ec100-redis",
        "SPRING_DATA_REDIS_PORT": "6379",
        "SPRING_DATA_REDIS_PASSWORD": secrets["redis_password"],
        "SPRING_REDIS_HOST": "ec100-redis",
        "SPRING_REDIS_PORT": "6379",
        "SPRING_REDIS_PASSWORD": secrets["redis_password"],
        "NACOS_SERVER_ADDR": "ec100-nacos:8848",
        "SPRING_CLOUD_NACOS_SERVER_ADDR": "ec100-nacos:8848",
        "SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR": "ec100-nacos:8848",
        "SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR": "ec100-nacos:8848",
        "SPRING_ACTIVITI_DATABASE_SCHEMA_UPDATE": "true",
        "SPRING_ACTIVITI_CHECK_PROCESS_DEFINITIONS": "false",
        "RUOYI_PROFILE": "/tmp/ec100-upload",
    }
    if plan["id"] == "ec042":
        values["SPRING_APPLICATION_JSON"] = json.dumps(
            {
                "spring": {"mvc": {"pathmatch": {"matching-strategy": "ant_path_matcher"}}},
                "ignore": {
                    "ignore-url": ["/account/login", "/account/sendCode", "/account/forget"],
                    "token-url": ["/upload/**", "/download/**"],
                },
                "filesave": {
                    "linux": "/tmp/ec042-files",
                    "windows": "C:/tmp/ec042-files",
                    "macos": "/tmp/ec042-files",
                    "upload-head": "/upload",
                    "local-head": "/tmp/ec042-files",
                },
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    elif plan["id"] == "ec088":
        values.update(
            {
                "SPRING_DATASOURCE_URL": "jdbc:h2:mem:ec088;MODE=MySQL;DB_CLOSE_DELAY=-1",
                "SPRING_DATASOURCE_USERNAME": "sa",
                "SPRING_DATASOURCE_PASSWORD": "",
                "SPRING_DATASOURCE_DRIVER_CLASS_NAME": "org.h2.Driver",
            }
        )
    elif plan["id"] == "ec087":
        values.update(
            {
                "DEPLOY_ADMIN_USER": "deployadmin",
                "DEPLOY_ADMIN_PASSWORD": secrets["preferred_application_admin_password"],
            }
        )
    elif plan["id"] == "ec091":
        values.update(
            {
                "SPRING_DATA_REDIS_HOST": "ec091-redis",
                "SPRING_DATA_REDIS_PORT": "6379",
                "SPRING_DATA_REDIS_PASSWORD": "",
                "SPRING_REDIS_HOST": "ec091-redis",
                "SPRING_REDIS_PORT": "6379",
                "SPRING_REDIS_PASSWORD": "",
                "SPRING_AI_OPENAI_EMBEDDING_BASE_URL": "http://ec091-embedding:8080/v1",
                "SPRING_AI_OPENAI_EMBEDDING_API_KEY": "deployment-stub",
            }
        )
    elif plan["id"] == "ec119":
        values.update(
            {
                "ZZYL_FRAMEWORK_OSS_ENDPOINT": "http://127.0.0.1",
                "ZZYL_FRAMEWORK_OSS_ACCESS_KEY_ID": "deployment-placeholder",
                "ZZYL_FRAMEWORK_OSS_ACCESS_KEY_SECRET": "deployment-placeholder",
                "ZZYL_FRAMEWORK_OSS_BUCKET_NAME": "eldercare-deployment",
                "DISABLE_ALIYUN_IOT": "1",
            }
        )
    elif plan["id"] == "ec154":
        # Upstream intentionally refuses to start without a 32+ character JWT
        # secret. Derive a stable deployment-only value from an existing
        # private server secret and keep it in the chmod-600 env file.
        values["CECSMS_JWT_SECRET"] = hashlib.sha256(
            f"{plan['id']}:{secrets['mysql_root_password']}".encode("utf-8")
        ).hexdigest()
        # The repository snapshot does not include the raster files referenced
        # by its seeded database. Keep the web/API system runnable while making
        # that missing-media boundary explicit in the acceptance report.
        values["APP_MEDIA_INTEGRITY_ENABLED"] = "false"
    elif plan["id"] == "ec157":
        # The OSS client validates configuration at bean construction time but
        # does not contact OSS until an upload operation is invoked. These
        # deployment-only values keep the local application runnable; external
        # OSS upload/delete remains outside the acceptance boundary.
        values.update(
            {
                "THIRDPARTY_ALIYUN_OSS_ENDPOINT": "http://127.0.0.1",
                "THIRDPARTY_ALIYUN_OSS_ACCESS_KEY_ID": "deployment-disabled",
                "THIRDPARTY_ALIYUN_OSS_ACCESS_KEY_SECRET": hashlib.sha256(
                    f"{plan['id']}:{secrets['redis_password']}".encode("utf-8")
                ).hexdigest(),
                "THIRDPARTY_ALIYUN_OSS_BACKET": "eldercare-deployment",
            }
        )
    elif plan["id"] == "ec163":
        # The upstream snapshot contains license headers in place of every
        # application profile, while the code requires these properties during
        # bean construction. Supply a local deployment profile; third-party
        # cloud values are deliberately non-production placeholders.
        deployment_secret = hashlib.sha256(
            f"{plan['id']}:{secrets['mysql_root_password']}".encode("utf-8")
        ).hexdigest()
        values.update(
            {
                "XSS_ENABLED": "true",
                "XSS_EXCLUDES": "/system/notice/*",
                "XSS_URLPATTERNS": "/*",
                "TOKEN_HEADER": "Authorization",
                "TOKEN_SECRET": deployment_secret,
                "TOKEN_EXPIRETIME": "30",
                "USER_PASSWORD_MAXRETRYCOUNT": "5",
                "USER_PASSWORD_LOCKTIME": "10",
                "SWAGGER_ENABLED": "true",
                "SWAGGER_PATHMAPPING": "/",
                "SPRING_DATASOURCE_DRUID_INITIALSIZE": "2",
                "SPRING_DATASOURCE_DRUID_MINIDLE": "2",
                "SPRING_DATASOURCE_DRUID_MAXACTIVE": "12",
                "SPRING_DATASOURCE_DRUID_MAXWAIT": "60000",
                "SPRING_DATASOURCE_DRUID_TIMEBETWEENEVICTIONRUNSMILLIS": "60000",
                "SPRING_DATASOURCE_DRUID_MINEVICTABLEIDLETIMEMILLIS": "300000",
                "SPRING_DATASOURCE_DRUID_MAXEVICTABLEIDLETIMEMILLIS": "900000",
                "SPRING_DATASOURCE_DRUID_VALIDATIONQUERY": "SELECT 1",
                "SPRING_DATASOURCE_DRUID_TESTWHILEIDLE": "true",
                "SPRING_DATASOURCE_DRUID_TESTONBORROW": "false",
                "SPRING_DATASOURCE_DRUID_TESTONRETURN": "false",
                "SPRING_DATASOURCE_DRUID_SLAVE_ENABLED": "false",
                "MYBATIS_TYPEALIASESPACKAGE": "cc.ruchu.rcare.**.domain",
                "MYBATIS_MAPPERLOCATIONS": "classpath*:mapper/**/*Mapper.xml",
                "MYBATIS_CONFIGLOCATION": "classpath:mybatis/mybatis-config.xml",
                "AUTHOR": "deployment",
                "PACKAGENAME": "cc.ruchu.rcare",
                "AUTOREMOVEPRE": "false",
                "TABLEPREFIX": "",
                "ALIYUN_OSS_ENDPOINT": "http://127.0.0.1",
                "ALIYUN_OSS_INTERNALENDPOINT": "http://127.0.0.1",
                "ALIYUN_OSS_QUICKENDPOINT": "http://127.0.0.1",
                "ALIYUN_OSS_ACCESSKEYID": "deployment-disabled",
                "ALIYUN_OSS_ACCESSKEYSECRET": deployment_secret,
                "ALIYUN_OSS_BUCKETNAME": "eldercare-deployment",
                "ALIYUN_OSS_ACCESSURL": "http://127.0.0.1",
                "ALIYUN_OSS_REGION": "local-disabled",
                "ALIYUN_STS_ACCESSKEYID": "deployment-disabled",
                "ALIYUN_STS_ACCESSKEYSECRET": deployment_secret,
                "ALIYUN_STS_ENDPOINT": "http://127.0.0.1",
                "ALIYUN_STS_ROLEARN": "deployment-disabled",
                "WEIXIN_CMINA_APPID": "deployment-disabled",
                "WEIXIN_CMINA_APPSECRET": deployment_secret,
                "WEIXIN_ZMINA_APPID": "deployment-disabled",
                "WEIXIN_ZMINA_APPSECRET": deployment_secret,
                "WEIXIN_SMINA_APPID": "deployment-disabled",
                "WEIXIN_SMINA_APPSECRET": deployment_secret,
            }
        )
    path.write_text("\n".join(f"{key}={value}" for key, value in values.items()) + "\n", encoding="utf-8")
    path.chmod(0o600)
    return path


def detect_backend_prefix(plan: dict[str, Any]) -> str:
    explicit = {"ec042": "/api"}
    if plan["id"] in explicit:
        return explicit[plan["id"]]
    frontend = plan.get("frontend") or {}
    if not frontend:
        return ""
    source = Path(frontend.get("remote_root", ""))
    relative = frontend.get("dir", ".")
    directory = source / ("" if relative == "." else relative)
    pattern = re.compile(
        r"(?m)^\s*(?:VITE_APP_BASE_API|VUE_APP_BASE_API)\s*=\s*['\"]?(/[^\s'\"]*)"
    )
    for name in (".env.production", ".env.prod", ".env"):
        path = directory / name
        if not path.is_file():
            continue
        try:
            match = pattern.search(path.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            continue
        if match:
            return match.group(1).rstrip("/")
    return ""


def mysql_execute(database: str, sql: str) -> None:
    result = run(
        [
            "docker",
            "exec",
            "ec100-mysql",
            "mysql",
            "--defaults-extra-file=/tmp/ec100-root.cnf",
            database,
            "-Nse",
            sql,
        ],
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout[-2000:])


def ensure_activiti_mysql_schema(project_id: str, database: str) -> None:
    exists = run(
        [
            "docker",
            "exec",
            "ec100-mysql",
            "mysql",
            "--defaults-extra-file=/tmp/ec100-root.cnf",
            database,
            "-Nse",
            "SELECT COUNT(*) FROM information_schema.tables "
            f"WHERE table_schema={sql_string(database)} AND table_name='ACT_GE_PROPERTY'",
        ],
        timeout=30,
    )
    if exists.returncode == 0 and exists.stdout.strip() not in {"", "0"}:
        return
    jar = ROOT / "apps" / project_id / "app.jar"
    if not jar.is_file():
        raise RuntimeError(f"missing {project_id} app.jar for Activiti schema")
    with zipfile.ZipFile(jar) as outer:
        engine_lib = next(
            (name for name in outer.namelist() if "activiti-engine-" in name and name.endswith(".jar")),
            "",
        )
        if not engine_lib:
            raise RuntimeError("Activiti engine library not found")
        with zipfile.ZipFile(io.BytesIO(outer.read(engine_lib))) as engine:
            for resource in (
                "org/activiti/db/create/activiti.mysql.create.engine.sql",
                "org/activiti/db/create/activiti.mysql.create.history.sql",
            ):
                mysql_execute(database, engine.read(resource).decode("utf-8", "replace"))


def sql_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def prepare_runtime(plan: dict[str, Any], secrets: dict[str, str]) -> None:
    if plan["id"] == "ec008":
        mysql_execute(
            plan["database_name"],
            "UPDATE sys_config SET config_value='false' "
            "WHERE config_key='sys.account.captchaEnabled'",
        )
    elif plan["id"] == "ec069":
        username = "deployadmin"
        password = secrets["preferred_application_admin_password"]
        mysql_execute(
            plan["database_name"],
            "INSERT INTO users(username,password,role,addtime) VALUES("
            f"{sql_string(username)},{sql_string(password)},'管理员',NOW()) "
            "ON DUPLICATE KEY UPDATE password=VALUES(password),role=VALUES(role)",
        )
    elif plan["id"] == "ec119":
        ensure_activiti_mysql_schema(plan["id"], plan["database_name"])


def start_java(
    plan: dict[str, Any], secrets: dict[str, str], build_result: dict[str, Any]
) -> dict[str, Any]:
    app_dir = ROOT / "apps" / plan["id"]
    jar = app_dir / "app.jar"
    if not jar.is_file():
        raise RuntimeError("missing app.jar")
    api_name = f"{plan['id']}-api"
    web_name = f"{plan['id']}-web"
    auxiliary_name = f"{plan['id']}-redis" if plan["id"] == "ec091" else ""
    embedding_name = f"{plan['id']}-embedding" if plan["id"] == "ec091" else ""
    cleanup_names = [api_name, web_name] + [name for name in (auxiliary_name, embedding_name) if name]
    run(["docker", "rm", "-f", *cleanup_names], timeout=60)
    if plan["id"] == "ec091":
        auxiliary = run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                auxiliary_name,
                "--network",
                "ec100_net",
                "--memory",
                "420m",
                "--cpus",
                "0.35",
                "--label",
                "com.kxb.task=eldercare100",
                "--label",
                f"com.kxb.project={plan['id']}",
                "redis/redis-stack-server:latest",
            ],
            timeout=300,
        )
        if auxiliary.returncode != 0:
            raise RuntimeError(auxiliary.stdout[-2000:])
        embedding = run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                embedding_name,
                "--network",
                "ec100_net",
                "--memory",
                "100m",
                "--cpus",
                "0.15",
                "--label",
                "com.kxb.task=eldercare100",
                "--label",
                f"com.kxb.project={plan['id']}",
                "-v",
                f"{EMBEDDING_STUB}:/stub.py:ro",
                "ec100/python-runtime:3",
                "python",
                "/stub.py",
            ],
            timeout=120,
        )
        if embedding.returncode != 0:
            raise RuntimeError(embedding.stdout[-2000:])
    env_file = write_env(plan, secrets)
    java_version = int((build_result.get("backend") or {}).get("java_version") or 17)
    runtime_image = f"maven:3.9-eclipse-temurin-{java_version}"
    api = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            api_name,
            "--network",
            "ec100_net",
            "--memory",
            "700m",
            "--cpus",
            "0.7",
            "--env-file",
            str(env_file),
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-v",
            f"{jar}:/app/app.jar:ro",
            runtime_image,
            "java",
            "-Xms128m",
            "-Xmx520m",
            "-Dfile.encoding=UTF-8",
            "-jar",
            "/app/app.jar",
        ]
    )
    if api.returncode != 0:
        raise RuntimeError(api.stdout[-2000:])
    web_dir = app_dir / "web"
    if web_dir.is_dir():
        backend_prefix = detect_backend_prefix(plan)
        web = run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                web_name,
                "--network",
                "ec100_net",
                "--memory",
                "160m",
                "--cpus",
                "0.2",
                "--label",
                "com.kxb.task=eldercare100",
                "--label",
                f"com.kxb.project={plan['id']}",
                "-e",
                "WEB_ROOT=/web",
                "-e",
                f"BACKEND_URL=http://{api_name}:8080",
                "-e",
                f"BACKEND_PREFIX={backend_prefix}",
                "-p",
                f"{plan['assigned_port']}:8080",
                "-v",
                f"{web_dir}:/web:ro",
                "-v",
                f"{GATEWAY}:/gateway.js:ro",
                "node:18-alpine",
                "node",
                "/gateway.js",
            ]
        )
        if web.returncode != 0:
            raise RuntimeError(web.stdout[-2000:])
        entry_url = f"http://{PUBLIC_HOST}:{plan['assigned_port']}/"
    else:
        run(["docker", "rm", "-f", api_name], timeout=60)
        api = run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                api_name,
                "--network",
                "ec100_net",
                "--memory",
                "700m",
                "--cpus",
                "0.7",
                "--env-file",
                str(env_file),
                "--label",
                "com.kxb.task=eldercare100",
                "--label",
                f"com.kxb.project={plan['id']}",
                "-p",
                f"{plan['assigned_port']}:8080",
                "-v",
                f"{jar}:/app/app.jar:ro",
                runtime_image,
                "java",
                "-Xms128m",
                "-Xmx520m",
                "-Dfile.encoding=UTF-8",
                "-jar",
                "/app/app.jar",
            ]
        )
        if api.returncode != 0:
            raise RuntimeError(api.stdout[-2000:])
        entry_url = f"http://{PUBLIC_HOST}:{plan['assigned_port']}/"
    return {"api_container": api_name, "web_container": web_name if web_dir.is_dir() else "", "entry_url": entry_url}


def start_dotnet(
    plan: dict[str, Any], secrets: dict[str, str], build_result: dict[str, Any]
) -> dict[str, Any]:
    backend = build_result.get("backend") or {}
    app_root = Path(backend.get("root", ""))
    entry_dll = str(backend.get("entry_dll", ""))
    dotnet_version = int(backend.get("dotnet_version") or 8)
    if not app_root.is_dir() or not (app_root / entry_dll).is_file():
        raise RuntimeError("missing published .NET application")
    api_name = f"{plan['id']}-api"
    web_name = f"{plan['id']}-web"
    db_name = f"{plan['id']}-db"
    run(["docker", "rm", "-f", api_name, web_name, db_name], timeout=60)
    database_password = secrets["preferred_application_admin_password"]
    db_env = write_private_env_file(
        plan["id"],
        "postgres",
        {
            "POSTGRES_DB": plan["database_name"],
            "POSTGRES_USER": plan["id"],
            "POSTGRES_PASSWORD": database_password,
        },
    )
    database = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            db_name,
            "--network",
            "ec100_net",
            "--memory",
            "420m",
            "--cpus",
            "0.35",
            "--env-file",
            str(db_env),
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-v",
            f"{plan['id']}-pgdata:/var/lib/postgresql/data",
            "postgres:16-alpine",
        ],
        timeout=180,
    )
    if database.returncode != 0:
        raise RuntimeError(database.stdout[-2000:])
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        ready = run(["docker", "exec", db_name, "pg_isready", "-U", plan["id"]], timeout=15)
        if ready.returncode == 0:
            break
        time.sleep(3)
    else:
        raise RuntimeError("PostgreSQL did not become ready")
    admin_email = f"deployadmin-{plan['id']}@example.local"
    api_env = write_private_env_file(
        plan["id"],
        "dotnet-api",
        {
            "ASPNETCORE_ENVIRONMENT": "Production",
            "ASPNETCORE_URLS": "http://+:8080",
            "ConnectionStrings__DefaultConnection": (
                f"Host={db_name};Port=5432;Database={plan['database_name']};"
                f"Username={plan['id']};Password={database_password};"
            ),
            "CORS_ALLOWED_ORIGINS": f"http://{PUBLIC_HOST}:{plan['assigned_port']}",
            "AllowInsecureHttpCookies": "true",
            "Bootstrap__InstitutionName": f"Eldercare 100 {plan['id']}",
            "Bootstrap__AdminEmail": admin_email,
            "Bootstrap__AdminDisplayName": "Deploy Admin",
        },
    )
    api = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            api_name,
            "--network",
            "ec100_net",
            "--memory",
            "850m",
            "--cpus",
            "0.7",
            "--env-file",
            str(api_env),
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-v",
            f"{app_root}:/app:ro",
            "-w",
            "/app",
            f"mcr.microsoft.com/dotnet/aspnet:{dotnet_version}.0-alpine",
            "dotnet",
            entry_dll,
        ],
        timeout=180,
    )
    if api.returncode != 0:
        raise RuntimeError(api.stdout[-2000:])
    web_dir = ROOT / "apps" / plan["id"] / "web"
    if not web_dir.is_dir():
        raise RuntimeError(".NET project has no built web frontend")
    backend_prefix = detect_backend_prefix(plan)
    web = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            web_name,
            "--network",
            "ec100_net",
            "--memory",
            "160m",
            "--cpus",
            "0.2",
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-e",
            "WEB_ROOT=/web",
            "-e",
            f"BACKEND_URL=http://{api_name}:8080",
            "-e",
            f"BACKEND_PREFIX={backend_prefix}",
            "-p",
            f"{plan['assigned_port']}:8080",
            "-v",
            f"{web_dir}:/web:ro",
            "-v",
            f"{GATEWAY}:/gateway.js:ro",
            "node:18-alpine",
            "node",
            "/gateway.js",
        ],
        timeout=180,
    )
    if web.returncode != 0:
        raise RuntimeError(web.stdout[-2000:])
    return {
        "api_container": api_name,
        "web_container": web_name,
        "database_container": db_name,
        "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
        "bootstrap_admin_email": admin_email,
    }


def start_java_war(
    plan: dict[str, Any], secrets: dict[str, str], build_result: dict[str, Any]
) -> dict[str, Any]:
    backend = build_result.get("backend") or {}
    war = Path(backend.get("war", ""))
    if not war.is_file():
        raise RuntimeError("missing WAR application")
    api_name = f"{plan['id']}-api"
    web_name = f"{plan['id']}-web"
    run(["docker", "rm", "-f", api_name, web_name], timeout=60)
    web_dir = ROOT / "apps" / plan["id"] / "web"
    direct_port = [] if web_dir.is_dir() else ["-p", f"{plan['assigned_port']}:8080"]
    if plan["id"] == "ec016":
        admin_username = "deployadmin"
        admin_password = secrets["preferred_application_admin_password"]
        quoted_user = admin_username.replace("'", "''")
        quoted_password = admin_password.replace("'", "''")
        mysql_execute(
            plan["database_name"],
            "CREATE TABLE IF NOT EXISTS admin ("
            "account varchar(255) NOT NULL PRIMARY KEY, "
            "password varchar(255) NULL); "
            "INSERT INTO admin(account,password) VALUES "
            f"('{quoted_user}','{quoted_password}') ON DUPLICATE KEY UPDATE password=VALUES(password)",
        )
    # Tomcat's catalina.sh expands JAVA_OPTS through eval.  An unquoted JDBC
    # query string containing '&' is therefore interpreted as shell control
    # syntax.  Keep the WAR runtime URL minimal; the legacy application already
    # defines its driver/encoding and only needs the target host/database.
    database_url = f"jdbc:mysql://ec100-mysql:3306/{plan['database_name']}"
    java_opts = (
        f"-Djdbc.url={database_url} -Djdbc.username=root "
        f"-Djdbc.password={secrets['mysql_root_password']} "
        f"-Djdbc_url={database_url} -Djdbc_username=root "
        f"-Djdbc_password={secrets['mysql_root_password']} -Dfile.encoding=UTF-8"
    )
    api = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            api_name,
            "--network",
            "ec100_net",
            "--memory",
            "700m",
            "--cpus",
            "0.7",
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            *direct_port,
            "-e",
            f"JAVA_OPTS={java_opts}",
            "-v",
            f"{war}:/usr/local/tomcat/webapps/ROOT.war:ro",
            "tomcat:9.0-jdk8-temurin",
        ],
        timeout=180,
    )
    if api.returncode != 0:
        raise RuntimeError(api.stdout[-2000:])
    if not web_dir.is_dir():
        return {
            "api_container": api_name,
            "web_container": "",
            "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
        }
    web = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            web_name,
            "--network",
            "ec100_net",
            "--memory",
            "160m",
            "--cpus",
            "0.2",
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-e",
            "WEB_ROOT=/web",
            "-e",
            f"BACKEND_URL=http://{api_name}:8080",
            "-e",
            "BACKEND_PREFIX=",
            "-p",
            f"{plan['assigned_port']}:8080",
            "-v",
            f"{web_dir}:/web:ro",
            "-v",
            f"{GATEWAY}:/gateway.js:ro",
            "node:18-alpine",
            "node",
            "/gateway.js",
        ],
        timeout=180,
    )
    if web.returncode != 0:
        raise RuntimeError(web.stdout[-2000:])
    return {
        "api_container": api_name,
        "web_container": web_name,
        "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
    }


def start_python(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    app_dir = ROOT / "apps" / plan["id"]
    backend_dir = app_dir / "backend"
    if not backend_dir.is_dir():
        raise RuntimeError("missing Python backend directory")
    api_name = f"{plan['id']}-api"
    web_name = f"{plan['id']}-web"
    run(["docker", "rm", "-f", api_name, web_name], timeout=60)
    web_dir = app_dir / "web"
    # A build metadata file alone is not a deployable frontend.  Static web
    # output must expose a root index.html; otherwise publish the Python app
    # directly (many Flask projects already ship their UI under backend/static).
    web_available = (web_dir / "index.html").is_file()
    direct_port = [] if web_available else ["-p", f"{plan['assigned_port']}:8080"]
    if plan["id"] == "ec030":
        app_path = backend_dir / "web" / "app.py"
        if app_path.is_file():
            source = app_path.read_text(encoding="utf-8", errors="replace")
            old = "        from main import init_system\n        init_system(app)"
            new = (
                "        if os.environ.get('DISABLE_CV') != '1':\n"
                "            from main import init_system\n"
                "            init_system(app)\n"
                "        else:\n"
                "            print('CV/camera initialization disabled for web deployment')"
            )
            if old in source:
                app_path.write_text(source.replace(old, new, 1), encoding="utf-8")
    elif plan["id"] == "ec023":
        app_init = backend_dir / "app" / "__init__.py"
        if app_init.is_file():
            source = app_init.read_text(encoding="utf-8", errors="replace")
            repaired = source.replace(
                "send_from_directory('static',", "send_from_directory('/app/static',"
            ).replace(
                "send_from_directory('../static',", "send_from_directory('/app/static',"
            )
            if repaired != source:
                app_init.write_text(repaired, encoding="utf-8")
    elif plan["id"] == "ec054":
        app_path = backend_dir / "app.py"
        if app_path.is_file():
            source = app_path.read_text(encoding="utf-8", errors="replace")
            repaired = source.replace("from routes.ai_agent import ai_bp\n", "")
            repaired = repaired.replace("from routes.knowledge import kb_bp\n", "")
            repaired = repaired.replace('app.register_blueprint(ai_bp, name="ai_module")\n', "")
            repaired = repaired.replace("app.register_blueprint(kb_bp)\n", "")
            if repaired != source:
                app_path.write_text(repaired, encoding="utf-8")
        ai_path = backend_dir / "routes" / "ai_agent.py"
        if ai_path.is_file():
            source = ai_path.read_text(encoding="utf-8", errors="replace")
            repaired = re.sub(r'(?m)^(API_KEY|BAIDU_API_KEY|BAIDU_SECRET_KEY)\s*=\s*"[^"]*"', r'\1 = ""', source)
            if repaired != source:
                ai_path.write_text(repaired, encoding="utf-8")
    elif plan["id"] == "ec078":
        settings_path = backend_dir / "webapp" / "settings.py"
        if settings_path.is_file():
            source = settings_path.read_text(encoding="utf-8", errors="replace")
            source = source.replace("import cx_Oracle\n", "")
            source = source.replace("from config import NAME, USER, PASSWORD\n", "")
            source = source.replace("'default': {\n        'ENGINE': 'django.db.backends.oracle',", "'default': {\n        'ENGINE': 'django.db.backends.sqlite3',")
            source = re.sub(
                r"'NAME': NAME,\s*'USER': USER,\s*'PASSWORD': PASSWORD,\s*'HOST': '127\.0\.0\.1',\s*'PORT': '1521',",
                "'NAME': BASE_DIR / 'db.sqlite3',",
                source,
                count=1,
            )
            settings_path.write_text(source, encoding="utf-8")
    elif plan["id"] == "ec082":
        config_path = backend_dir / "config.py"
        if config_path.is_file():
            source = config_path.read_text(encoding="utf-8", errors="replace")
            source = re.sub(
                r"(?m)^SQLALCHEMY_DATABASE_URI\s*=.*$",
                "SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')",
                source,
                count=1,
            )
            config_path.write_text(source, encoding="utf-8")
        init_path = backend_dir / "app" / "__init__.py"
        if init_path.is_file():
            source = init_path.read_text(encoding="utf-8", errors="replace")
            source = source.replace("async_mode='eventlet'", "async_mode='threading'")
            init_path.write_text(source, encoding="utf-8")
    elif plan["id"] == "ec092":
        config_path = backend_dir / "config.py"
        if config_path.is_file():
            source = config_path.read_text(encoding="utf-8", errors="replace")
            source = re.sub(
                r"SQLALCHEMY_DATABASE_URI\s*=\s*\(\s*['\"]mysql\+mysqlconnector:[^'\"]*['\"]\s*\)",
                "SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')",
                source,
                count=1,
                flags=re.DOTALL,
            )
            config_path.write_text(source, encoding="utf-8")
    elif plan["id"] == "ec097":
        config_path = backend_dir / "config.py"
        if not config_path.is_file():
            config_path.write_text(
                """import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'eldercare-deployment-secret')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'eldercare-deployment-jwt-secret')
    DASHSCOPE_API_KEY = os.environ.get('DASHSCOPE_API_KEY', '')
    DASHSCOPE_BASE_URL = os.environ.get('DASHSCOPE_BASE_URL', 'https://dashscope.aliyuncs.com/compatible-mode/v1')
    DASHSCOPE_MODEL = os.environ.get('DASHSCOPE_MODEL', 'qwen-flash')
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER', '/tmp/ec097-uploads')

    @staticmethod
    def init_app(app):
        os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)

class DevelopmentConfig(Config):
    DEBUG = False

class ProductionConfig(Config):
    DEBUG = False

class TestingConfig(Config):
    TESTING = True

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig,
}
""",
                encoding="utf-8",
            )
    if plan["id"] == "ec082":
        launch = (
            "python -c \"import os,hashlib; from app import app,db; "
            "from app.mod_user.models import User; app.app_context().push(); db.create_all(); "
            "u=User.query.filter_by(email='deployadmin@ec082.local').first() or "
            "User(id=None,username='deployadmin',email='deployadmin@ec082.local',real_name='Deploy Admin',isactive='1'); "
            "u.password=hashlib.md5(os.environ['DEPLOY_ADMIN_PASSWORD'].encode()).hexdigest(); "
            "db.session.add(u); db.session.commit()\"; "
            "gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 120 app:app"
        )
    elif plan["id"] == "ec090":
        launch = "uvicorn api.app:app --host 0.0.0.0 --port 8080"
    elif plan["id"] == "ec092":
        launch = (
            "python -c \"import os; from run import app,db; from app.models import User; "
            "from werkzeug.security import generate_password_hash; "
            "app.app_context().push(); db.create_all(); "
            "u=User.query.filter_by(email='deployadmin-ec092@example.com').first() or "
            "User(username='deployadmin92',email='deployadmin-ec092@example.com',role='caregiver'); "
            "u.password_hash=generate_password_hash(os.environ['DEPLOY_ADMIN_PASSWORD'],method='pbkdf2:sha256'); "
            "db.session.add(u); db.session.commit()\"; "
            "gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 120 run:app"
        )
    elif plan["id"] == "ec097":
        launch = "gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 120 run:app"
    elif plan["id"] == "ec104":
        launch = "python -m http.server 8080 --bind 0.0.0.0"
    elif (backend_dir / "manage.py").is_file():
        launch = "python manage.py migrate --noinput || true; python manage.py runserver 0.0.0.0:8080 --noreload"
    elif (backend_dir / "app.py").is_file():
        launch = "gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 120 app:app"
    elif (backend_dir / "run.py").is_file():
        prefix = "python init_db.py; " if (backend_dir / "init_db.py").is_file() else ""
        launch = prefix + "gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 120 run:app"
    elif (backend_dir / "app" / "main.py").is_file():
        launch = "uvicorn app.main:app --host 0.0.0.0 --port 8080"
    elif (backend_dir / "web" / "server.py").is_file():
        launch = "uvicorn web.server:app --host 0.0.0.0 --port 8080"
    elif (backend_dir / "api" / "app.py").is_file():
        launch = "uvicorn api.app:app --host 0.0.0.0 --port 8080"
    elif (backend_dir / "api" / "main.py").is_file():
        launch = "uvicorn api.main:app --host 0.0.0.0 --port 8080"
    elif (backend_dir / "main.py").is_file():
        launch = "python main.py"
    else:
        ignored = {"__init__.py", "init_db.py", "init_admin.py", "download_models.py"}
        entry = next((item for item in sorted(backend_dir.glob("*.py")) if item.name not in ignored), None)
        if entry is None:
            raise RuntimeError("no Python entry point found")
        launch = f"python {entry.name}"
    if plan["id"] == "ec022":
        # Upstream omitted its dependency manifest.  Django 4.2 is the oldest
        # supported LTS line that also runs on the shared Python 3.12 image.
        install = (
            "apt-get update >/dev/null && "
            "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "
            "libglib2.0-0 libpango-1.0-0 libpangoft2-1.0-0 libcairo2 libgdk-pixbuf-2.0-0 >/dev/null; "
            "pip install --no-cache-dir 'Django>=4.2,<5' weasyprint; "
        )
    elif plan["id"] == "ec030":
        # Keep the web/database/login system runnable without downloading the
        # optional multi-gigabyte CUDA/YOLO/dlib stack on every container start.
        install = (
            "pip install --no-cache-dir Flask Flask-SQLAlchemy Flask-Login "
            "opencv-python-headless 'numpy<2' Pillow waitress gunicorn PyMySQL; "
        )
    elif plan["id"] == "ec078":
        # The upstream pins an Oracle-only driver and Django 3.2, neither of
        # which is usable in the shared Python 3.12 runtime.  The application
        # already declares a SQLite database, so deploy against local SQLite.
        install = (
            "pip install --no-cache-dir 'Django>=4.2,<5' "
            "'django-crispy-forms>=1.14,<2' django-model-utils gunicorn; "
        )
    elif plan["id"] == "ec082":
        install = (
            "pip install --no-cache-dir 'Flask==2.0.3' 'Werkzeug==2.0.3' "
            "'Jinja2==3.0.3' 'itsdangerous==2.0.1' 'Flask-Login==0.5.0' "
            "'Flask-SQLAlchemy==2.5.1' 'SQLAlchemy<2' 'Flask-SocketIO>=5.3,<6' "
            "Flask-HTTPAuth Flask-RESTful Flask-Session mysql-connector-python "
            "PyMySQL redis requests eventlet 'greenlet>=3' paho-mqtt pymodbus "
            "'numpy<2' opencv-python-headless gunicorn; "
        )
    elif plan["id"] == "ec090":
        install = "pip install --no-cache-dir -r requirements.txt; "
    elif plan["id"] == "ec092":
        install = (
            "pip install --no-cache-dir 'Flask>=2.3,<3' 'Werkzeug<3' "
            "'Flask-SQLAlchemy>=3,<4' 'Flask-Login>=0.6,<1' 'Flask-WTF>=1.2,<2' "
            "PyMySQL twilio python-dotenv WTForms email-validator scikit-learn pandas numpy gunicorn; "
        )
    elif plan["id"] == "ec104":
        install = ""
    elif plan["id"] == "ec156":
        install = (
            "apt-get update >/dev/null && "
            "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "
            "libglib2.0-0t64 libxcb1 libx11-6 libxext6 libxrender1 libgl1 >/dev/null; "
            "pip install --no-cache-dir -r requirements.txt; "
        )
    elif plan["id"] == "ec166":
        install = "pip install --no-cache-dir -r requirements.txt PyMySQL; "
    else:
        install = (
            "if [ -f requirements.txt ]; then "
            "pip install --no-cache-dir -r requirements.txt; fi; "
        )
    if plan["id"] == "ec054":
        install += "pip install --no-cache-dir requests APScheduler; "
    command = install + launch
    mysql_password = urllib.parse.quote_plus(secrets["mysql_root_password"])
    redis_password = urllib.parse.quote_plus(secrets["redis_password"])
    database_url = (
        f"mysql+pymysql://root:{mysql_password}@ec100-mysql:3306/{plan['database_name']}"
    )
    if plan["id"] in {"ec159", "ec166"}:
        database_url = "sqlite:////app/eldercare.db"
    redis_url = f"redis://:{redis_password}@ec100-redis:6379/0"
    runtime_env = [
        "-e",
        f"DATABASE_URL={database_url}",
        "-e",
        "MYSQL_HOST=ec100-mysql",
        "-e",
        "MYSQL_PORT=3306",
        "-e",
        f"MYSQL_DATABASE={plan['database_name']}",
        "-e",
        "MYSQL_USER=root",
        "-e",
        f"MYSQL_PASSWORD={secrets['mysql_root_password']}",
        "-e",
        f"REDIS_URL={redis_url}",
        "-e",
        f"CELERY_BROKER_URL={redis_url}",
        "-e",
        f"CELERY_RESULT_BACKEND={redis_url}",
    ]
    if plan["id"] in {"ec082", "ec092"}:
        runtime_env.extend(
            ["-e", f"DEPLOY_ADMIN_PASSWORD={secrets['preferred_application_admin_password']}"]
        )
    if plan["id"] == "ec030":
        runtime_env.extend(["-e", "DISABLE_CV=1"])
    if plan["id"] == "ec166":
        main_path = backend_dir / "app" / "main.py"
        if main_path.is_file():
            source = main_path.read_text(encoding="utf-8", errors="replace")
            if "import os\n" not in source:
                source = "import os\n" + source
            if "MQTT integration disabled for deployment acceptance" not in source:
                source = source.replace(
                    "    mqtt_manager.connect_mqtt()",
                    "    if os.environ.get('DISABLE_MQTT') != '1':\n"
                    "        mqtt_manager.connect_mqtt()\n"
                    "    else:\n"
                    "        print('MQTT integration disabled for deployment acceptance')",
                    1,
                )
                source = source.replace(
                    "    mqtt_manager.disconnect_mqtt()",
                    "    if os.environ.get('DISABLE_MQTT') != '1':\n"
                    "        mqtt_manager.disconnect_mqtt()",
                    1,
                )
            main_path.write_text(source, encoding="utf-8")
        runtime_env.extend(["-e", "DISABLE_MQTT=1"])
    api = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            api_name,
            "--network",
            "ec100_net",
            "--memory",
            "900m",
            "--cpus",
            "0.7",
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            *direct_port,
            "-e",
            "FLASK_ENV=production",
            "-e",
            "USE_HADOOP=False",
            *runtime_env,
            "-v",
            f"{backend_dir}:/app",
            "-w",
            "/app",
            "ec100/python-runtime:3",
            "sh",
            "-lc",
            command,
        ]
    )
    if api.returncode != 0:
        raise RuntimeError(api.stdout[-2000:])
    if web_available:
        backend_prefix = detect_backend_prefix(plan)
        web = run(
            [
                "docker",
                "run",
                "-d",
                "--name",
                web_name,
                "--network",
                "ec100_net",
                "--memory",
                "160m",
                "--cpus",
                "0.2",
                "--label",
                "com.kxb.task=eldercare100",
                "--label",
                f"com.kxb.project={plan['id']}",
                "-e",
                "WEB_ROOT=/web",
                "-e",
                f"BACKEND_URL=http://{api_name}:8080",
                "-e",
                f"BACKEND_PREFIX={backend_prefix}",
                "-p",
                f"{plan['assigned_port']}:8080",
                "-v",
                f"{web_dir}:/web:ro",
                "-v",
                f"{GATEWAY}:/gateway.js:ro",
                "node:18-alpine",
                "node",
                "/gateway.js",
            ]
        )
        if web.returncode != 0:
            raise RuntimeError(web.stdout[-2000:])
    else:
        return {
            "api_container": api_name,
            "web_container": "",
            "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
        }
    return {
        "api_container": api_name,
        "web_container": web_name,
        "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
    }


def start_static(plan: dict[str, Any]) -> dict[str, Any]:
    web_dir = ROOT / "apps" / plan["id"] / "web"
    if not (web_dir / "index.html").is_file():
        raise RuntimeError("missing static web index.html")
    web_name = f"{plan['id']}-web"
    run(["docker", "rm", "-f", web_name], timeout=60)
    web = run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            web_name,
            "--network",
            "ec100_net",
            "--memory",
            "128m",
            "--cpus",
            "0.2",
            "--label",
            "com.kxb.task=eldercare100",
            "--label",
            f"com.kxb.project={plan['id']}",
            "-p",
            f"{plan['assigned_port']}:80",
            "-v",
            f"{web_dir}:/usr/share/nginx/html:ro",
            "nginx:alpine",
        ],
        timeout=180,
    )
    if web.returncode != 0:
        raise RuntimeError(web.stdout[-2000:])
    return {
        "api_container": "",
        "web_container": web_name,
        "entry_url": f"http://{PUBLIC_HOST}:{plan['assigned_port']}/",
    }


def verify_ec043_backend(plan: dict[str, Any]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    api = wait_http(base + "/api/key/indicators", seconds=240)
    api_json = parse_json_response(api)
    ready = api["http_status"] == 200 and api_json is not None
    return {
        "status": "ui-login-pending" if ready else "login-failed",
        "username": "admin",
        "password": "123456",
        "login_url": public_base + "/login",
        "business_endpoint": public_base + "/api/key/indicators",
        "business_http": api["http_status"],
        "business_json_received": api_json is not None,
        "authentication_model": "browser-localStorage",
        "response_excerpt": api["body"][:1000],
    }


def verify_ec087(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin"
    password = secrets["preferred_application_admin_password"]
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    login = opener_form_request(
        opener,
        base + "/root/loginIn",
        {"username": username, "password": password, "power": "0"},
    )
    login_json = parse_json_response(login)
    dashboard = opener_request(opener, base + "/indexA")
    success = (
        login["http_status"] == 200
        and login_json is not None
        and login_json.get("code") == 1
        and dashboard["http_status"] == 200
        and "养老院后台管理系统" in dashboard["body"]
        and len(list(jar)) > 0
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password_secret_key": "preferred_application_admin_password",
        "credential_origin": "deployment completion for upstream snapshot missing MVC controllers",
        "login_url": public_base + "/",
        "api_login_url": public_base + "/root/loginIn",
        "login_http": login["http_status"],
        "login_code": login_json.get("code") if login_json else None,
        "session_cookie_received": len(list(jar)) > 0,
        "business_http": dashboard["http_status"],
        "business_endpoint": public_base + "/indexA",
    }


def verify_ec082(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin@ec082.local"
    password = secrets["preferred_application_admin_password"]
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    login = opener_form_request(
        opener,
        base + "/login",
        {"email": username, "password": password},
    )
    dashboard = opener_request(opener, base + "/datamanage")
    success = (
        login["http_status"] == 200
        and dashboard["http_status"] == 200
        and len(list(jar)) > 0
        and "智慧养老" in dashboard["body"]
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password_secret_key": "preferred_application_admin_password",
        "login_url": public_base + "/login",
        "login_http": login["http_status"],
        "session_cookie_received": len(list(jar)) > 0,
        "business_http": dashboard["http_status"],
        "business_endpoint": public_base + "/datamanage",
    }


def verify_ec092(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin-ec092@example.com"
    password = secrets["preferred_application_admin_password"]
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    readiness = opener_request(opener, base + "/login")
    match = re.search(r'name=["\']csrf_token["\'][^>]*value=["\']([^"\']+)', readiness["body"])
    if match is None:
        match = re.search(r'value=["\']([^"\']+)["\'][^>]*name=["\']csrf_token', readiness["body"])
    csrf_token = match.group(1) if match else ""
    login = opener_form_request(
        opener,
        base + "/login",
        {
            "email": username,
            "password": password,
            "remember_me": "y",
            "csrf_token": csrf_token,
        },
    )
    dashboard = opener_request(opener, base + "/dashboard")
    success = (
        readiness["http_status"] == 200
        and bool(csrf_token)
        and login["http_status"] == 200
        and dashboard["http_status"] == 200
        and len(list(jar)) > 0
        and "dashboard" in dashboard["body"].lower()
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password_secret_key": "preferred_application_admin_password",
        "login_url": public_base + "/login",
        "csrf_received": bool(csrf_token),
        "login_http": login["http_status"],
        "session_cookie_received": len(list(jar)) > 0,
        "business_http": dashboard["http_status"],
        "business_endpoint": public_base + "/dashboard",
    }


def verify_ec097(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin97"
    phone = "13900000097"
    password = secrets["preferred_application_admin_password"][:16]

    def attempt_login() -> tuple[dict[str, Any], dict[str, Any] | None]:
        response = http_request(
            base + "/api/auth/login",
            method="POST",
            data={"phone": username, "password": password},
        )
        return response, parse_json_response(response)

    login, login_json = attempt_login()
    if login["http_status"] != 200:
        http_request(
            base + "/api/auth/register",
            method="POST",
            data={
                "phone": phone,
                "password": password,
                "user_name": username,
                "user_type": "elder",
            },
        )
        login, login_json = attempt_login()
    token = ""
    if login_json and isinstance(login_json.get("data"), dict):
        token = str(login_json["data"].get("access_token") or "")
    business = http_request(
        base + "/api/auth/user/profile",
        headers={"Authorization": f"Bearer {token}"} if token else None,
    )
    business_json = parse_json_response(business)
    success = (
        login["http_status"] == 200
        and login_json is not None
        and bool(token)
        and business["http_status"] == 200
        and business_json is not None
        and isinstance(business_json.get("data"), dict)
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password": password,
        "login_url": public_base + "/api/auth/login",
        "login_http": login["http_status"],
        "token_received": bool(token),
        "business_http": business["http_status"],
        "business_endpoint": public_base + "/api/auth/user/profile",
        "business_json_received": business_json is not None,
        "response_excerpt": json.dumps(
            {key: value for key, value in (login_json or {}).items() if key != "data"},
            ensure_ascii=False,
        )[:1000],
    }


def verify_ec095_request_auth(plan: dict[str, Any]) -> dict[str, Any]:
    path = "/api/stats"
    deadline = time.monotonic() + 180
    response = {"http_status": 0, "body": "", "error": "not attempted"}
    while time.monotonic() < deadline:
        timestamp = str(int(time.time() * 1000))
        nonce = hashlib.sha256(f"{timestamp}-{plan['id']}".encode()).hexdigest()[:24]
        payload = f"GET|{path}|{timestamp}|{nonce}|community-elderly-2026"
        signature = hashlib.sha256(payload.encode()).hexdigest()
        response = http_request(
            f"http://127.0.0.1:{plan['assigned_port']}{path}",
            headers={
                "X-Timestamp": timestamp,
                "X-Nonce": nonce,
                "X-Signature": signature,
                "X-Role": "staff",
            },
        )
        if response["http_status"] not in (0, 502, 503, 504):
            break
        time.sleep(2)
    parsed = parse_json_response(response)
    return {
        "status": "request-auth-verified" if response["http_status"] == 200 and parsed is not None else "request-auth-failed",
        "auth_scheme": "signed-request-plus-role",
        "business_http": response["http_status"],
        "business_endpoint": f"http://{PUBLIC_HOST}:{plan['assigned_port']}{path}",
        "business_json_received": parsed is not None,
        "http_response": response,
    }


def verify_ec069(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}/springbootu1yrv"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}/springbootu1yrv"
    username = "deployadmin"
    password = secrets["preferred_application_admin_password"]
    deadline = time.monotonic() + 180
    login = {"http_status": 0, "body": "", "error": "not attempted"}
    login_json = None
    while time.monotonic() < deadline:
        login = form_request(
            base + "/users/login",
            {"username": username, "password": password, "captcha": ""},
            timeout=8,
        )
        login_json = parse_json_response(login)
        if login["http_status"] == 200 and login_json is not None:
            break
        time.sleep(3)
    token = str((login_json or {}).get("token") or "")
    business = http_request(
        base + "/config/list",
        headers={"Token": token} if token else None,
    )
    business_json = parse_json_response(business)
    success = (
        login["http_status"] == 200
        and login_json is not None
        and bool(token)
        and business["http_status"] == 200
        and business_json is not None
        and business_json.get("code") == 0
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password_secret_key": "preferred_application_admin_password",
        "login_url": public_base + "/admin/dist/index.html",
        "api_login_url": public_base + "/users/login",
        "login_http": login["http_status"],
        "login_code": login_json.get("code") if login_json else None,
        "token_received": bool(token),
        "business_http": business["http_status"],
        "business_code": business_json.get("code") if business_json else None,
        "business_endpoint": public_base + "/config/list",
        "response_excerpt": json.dumps(
            {key: value for key, value in (login_json or {}).items() if key != "token"},
            ensure_ascii=False,
        )[:1000],
    }


def verify_ec002(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    email = f"deployadmin-{plan['id']}@example.local"
    password = secrets["preferred_application_admin_password"]
    readiness = wait_api_response(
        base + "/api/v1/Auth/login",
        method="POST",
        data={"email": "readiness@example.invalid", "password": "__invalid__"},
        seconds=240,
    )
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    login = opener_request(
        opener,
        base + "/api/v1/Auth/login",
        method="POST",
        data={"email": email, "password": password},
    )
    login_json = parse_json_response(login)
    activated = False
    activation_http = 0
    if login["http_status"] != 200 or not login_json or login_json.get("status") != "ok":
        logs = run(["docker", "logs", f"{plan['id']}-api"], timeout=60).stdout
        token_match = re.search(r"Token de ativa[^:]*:\s*(\S+)", logs)
        if token_match:
            activation = http_request(
                base + "/api/v1/Auth/activate",
                method="POST",
                data={"email": email, "token": token_match.group(1), "newPassword": password},
            )
            activation_http = activation["http_status"]
            activated = activation_http == 200
            jar = http.cookiejar.CookieJar()
            opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
            login = opener_request(
                opener,
                base + "/api/v1/Auth/login",
                method="POST",
                data={"email": email, "password": password},
            )
            login_json = parse_json_response(login)
    mfa_flow = "none"
    mfa_http = 0
    if login_json and login_json.get("status") in {"mfa_enrollment_required", "mfa_required"}:
        challenge = str(login_json.get("challengeToken") or "")
        secret_path = ROOT / "private" / "apps" / f"{plan['id']}-mfa-secret.txt"
        secret = secret_path.read_text(encoding="utf-8").strip() if secret_path.is_file() else ""
        if login_json.get("status") == "mfa_enrollment_required":
            enroll = opener_request(
                opener,
                base + "/api/v1/Auth/mfa/enroll",
                method="POST",
                data={"challengeToken": challenge},
            )
            enroll_json = parse_json_response(enroll)
            secret = str((enroll_json or {}).get("authenticatorKey") or "")
            if secret:
                secret_path.write_text(secret + "\n", encoding="utf-8")
                secret_path.chmod(0o600)
                confirm = opener_request(
                    opener,
                    base + "/api/v1/Auth/mfa/confirm",
                    method="POST",
                    data={"challengeToken": challenge, "code": totp_code(secret)},
                )
                mfa_flow = "enrolled-and-confirmed"
                mfa_http = confirm["http_status"]
                if confirm["http_status"] == 200:
                    login_json = {"status": "ok", "identity": (parse_json_response(confirm) or {}).get("identity")}
                    login = confirm
        elif secret:
            verified = opener_request(
                opener,
                base + "/api/v1/Auth/login/mfa",
                method="POST",
                data={"challengeToken": challenge, "code": totp_code(secret)},
            )
            mfa_flow = "verified-existing"
            mfa_http = verified["http_status"]
            if verified["http_status"] == 200:
                login_json = parse_json_response(verified)
                login = verified
    me = opener_request(opener, base + "/api/v1/Auth/me")
    me_json = parse_json_response(me)
    business = opener_request(opener, base + "/api/v1/Religion?page=1&pageSize=10")
    business_json = parse_json_response(business)
    success = (
        readiness["http_status"] not in (0, 502, 503, 504)
        and login["http_status"] == 200
        and login_json is not None
        and login_json.get("status") == "ok"
        and me["http_status"] == 200
        and me_json is not None
        and business["http_status"] == 200
        and business_json is not None
        and len(list(jar)) > 0
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": email,
        "password": password,
        "login_url": public_base + "/login",
        "api_login_url": public_base + "/api/v1/Auth/login",
        "readiness_http": readiness["http_status"],
        "activation_attempted": activated or bool(activation_http),
        "activation_http": activation_http,
        "login_http": login["http_status"],
        "login_status": login_json.get("status") if login_json else None,
        "mfa_flow": mfa_flow,
        "mfa_http": mfa_http,
        "session_cookie_received": len(list(jar)) > 0,
        "authenticated_me_http": me["http_status"],
        "business_http": business["http_status"],
        "business_endpoint": public_base + "/api/v1/Religion?page=1&pageSize=10",
        "business_json_received": business_json is not None,
        "response_excerpt": login["body"][:1000],
    }


def verify_ec016(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin"
    password = secrets["preferred_application_admin_password"]
    deadline = time.monotonic() + 180
    login = {"http_status": 0, "body": "", "error": "not attempted"}
    login_json = None
    while time.monotonic() < deadline:
        login = form_request(
            base + "/admin/login",
            {"account": username, "password": password},
            timeout=8,
        )
        login_json = parse_json_response(login)
        if login["http_status"] == 200 and login_json is not None:
            break
        time.sleep(3)
    business = http_request(base + "/parent/list")
    business_json = None
    try:
        business_json = json.loads(business["body"])
    except json.JSONDecodeError:
        pass
    login_ok = (
        login["http_status"] == 200
        and login_json is not None
        and str(login_json.get("adminAccount", login_json.get("account", ""))) == username
    )
    return {
        "status": "login-unprotected" if login_ok and business["http_status"] == 200 else "login-failed",
        "username": username,
        "password": password,
        "login_url": public_base + "/",
        "api_login_url": public_base + "/admin/login",
        "login_http": login["http_status"],
        "login_object_received": login_json is not None,
        "business_http": business["http_status"],
        "business_endpoint": public_base + "/parent/list",
        "business_json_received": business_json is not None,
        "protected_business_endpoint": False,
        "acceptance_note": "upstream application does not enforce a session or token on business endpoints",
        "response_excerpt": login["body"][:1000],
    }


def verify_ec006(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "deployadmin"
    password = secrets["preferred_application_admin_password"]
    readiness = wait_api_response(
        base + "/user/login",
        method="POST",
        data={"username": "__readiness_probe__", "password": "__invalid__"},
        seconds=180,
    )
    readiness_json = parse_json_response(readiness)
    if readiness_json is None or readiness["http_status"] in (0, 502, 503, 504):
        return {
            "status": "login-failed",
            "username": username,
            "password": password,
            "login_url": public_base + "/#/login",
            "api_login_url": public_base + "/user/login",
            "readiness_http": readiness["http_status"],
            "response_excerpt": readiness["body"][:1000],
            "error": readiness["error"] or "backend API did not become ready",
        }
    register = http_request(
        base + "/user/register",
        method="POST",
        data={
            "username": username,
            "password": password,
            "realName": "部署管理员",
            "role": "ADMIN",
            "status": 1,
        },
    )
    login = http_request(
        base + "/user/login",
        method="POST",
        data={"username": username, "password": password},
    )
    register_json = parse_json_response(register)
    login_json = parse_json_response(login)
    token = None
    if login_json and isinstance(login_json.get("data"), dict):
        token = login_json["data"].get("token")
    success = (
        login["http_status"] == 200
        and login_json is not None
        and login_json.get("code") == 200
        and login_json.get("message") == "登录成功"
        and isinstance(token, str)
        and bool(token)
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password": password,
        "login_url": public_base + "/#/login",
        "api_login_url": public_base + "/user/login",
        "readiness_http": readiness["http_status"],
        "readiness_code": readiness_json.get("code"),
        "register_http": register["http_status"],
        "register_code": register_json.get("code") if register_json else None,
        "register_message": register_json.get("message") if register_json else "",
        "login_http": login["http_status"],
        "login_code": login_json.get("code") if login_json else None,
        "token_received": bool(token),
        "response_excerpt": login["body"][:1000],
    }


def verify_ec008(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "admin"
    password = "admin123"
    readiness = wait_api_response(
        base + "/prod-api/login",
        method="POST",
        data={"username": "__readiness_probe__", "password": "__invalid__", "code": "", "uuid": ""},
        seconds=240,
    )
    readiness_json = parse_json_response(readiness)
    if readiness_json is None or readiness["http_status"] in (0, 502, 503, 504):
        return {
            "status": "login-failed",
            "username": username,
            "password": password,
            "login_url": public_base + "/login",
            "api_login_url": public_base + "/prod-api/login",
            "readiness_http": readiness["http_status"],
            "response_excerpt": readiness["body"][:1000],
            "error": readiness["error"] or "backend API did not become ready",
        }
    login = http_request(
        base + "/prod-api/login",
        method="POST",
        data={"username": username, "password": password, "code": "", "uuid": ""},
    )
    login_json = parse_json_response(login)
    token = login_json.get("token") if login_json else None
    info = {"http_status": 0, "body": "", "error": "token missing"}
    info_json = None
    if isinstance(token, str) and token:
        info = http_request(
            base + "/prod-api/getInfo",
            headers={"Authorization": "Bearer " + token},
        )
        info_json = parse_json_response(info)
    success = (
        login["http_status"] == 200
        and login_json is not None
        and login_json.get("code") == 200
        and isinstance(token, str)
        and bool(token)
        and info["http_status"] == 200
        and info_json is not None
        and info_json.get("code") == 200
        and isinstance(info_json.get("user"), dict)
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password": password,
        "login_url": public_base + "/login",
        "api_login_url": public_base + "/prod-api/login",
        "readiness_http": readiness["http_status"],
        "readiness_code": readiness_json.get("code"),
        "login_http": login["http_status"],
        "login_code": login_json.get("code") if login_json else None,
        "token_received": bool(token),
        "authenticated_info_http": info["http_status"],
        "authenticated_info_code": info_json.get("code") if info_json else None,
        "response_excerpt": login["body"][:1000],
    }


def verify_ec042(plan: dict[str, Any], secrets: dict[str, str]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "13547584400"
    password = "123456"
    readiness = wait_api_response(
        base + "/api/account/login",
        method="POST",
        data={"phone": "13500000000", "pass": "__invalid__"},
        seconds=240,
    )
    readiness_json = parse_json_response(readiness)
    if readiness_json is None or readiness["http_status"] in (0, 502, 503, 504):
        return {
            "status": "login-failed",
            "username": username,
            "password": password,
            "login_url": public_base + "/login",
            "api_login_url": public_base + "/api/account/login",
            "readiness_http": readiness["http_status"],
            "response_excerpt": readiness["body"][:1000],
            "error": readiness["error"] or "backend API did not become ready",
        }
    login = http_request(
        base + "/api/account/login",
        method="POST",
        data={"phone": username, "pass": password},
    )
    login_json = parse_json_response(login)
    token = None
    if login_json and isinstance(login_json.get("data"), dict):
        token = login_json["data"].get("token")
    business = {"http_status": 0, "body": "", "error": "token missing"}
    business_json = None
    if isinstance(token, str) and token:
        business = http_request(
            base + "/api/home/todayOverview",
            headers={"token": token},
        )
        business_json = parse_json_response(business)
    success = (
        login["http_status"] == 200
        and login_json is not None
        and login_json.get("code") == 200
        and isinstance(token, str)
        and bool(token)
        and business["http_status"] == 200
        and business_json is not None
        and business_json.get("code") == 200
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password": password,
        "login_url": public_base + "/login",
        "api_login_url": public_base + "/api/account/login",
        "readiness_http": readiness["http_status"],
        "readiness_code": readiness_json.get("code"),
        "login_http": login["http_status"],
        "login_code": login_json.get("code") if login_json else None,
        "token_received": bool(token),
        "business_http": business["http_status"],
        "business_code": business_json.get("code") if business_json else None,
        "business_endpoint": public_base + "/api/home/todayOverview",
        "response_excerpt": login["body"][:1000],
    }


def verify_ec166(plan: dict[str, Any]) -> dict[str, Any]:
    base = f"http://127.0.0.1:{plan['assigned_port']}"
    public_base = f"http://{PUBLIC_HOST}:{plan['assigned_port']}"
    username = "admin"
    password = "admin123"
    login = form_request(
        base + "/api/v1/auth/token",
        {"username": username, "password": password},
        timeout=20,
    )
    login_json = parse_json_response(login)
    token = login_json.get("access_token") if login_json else ""
    profile = {"http_status": 0, "body": "", "error": "token missing"}
    profile_json = None
    if isinstance(token, str) and token:
        profile = http_request(
            base + "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=20,
        )
        profile_json = parse_json_response(profile)
    success = (
        login["http_status"] == 200
        and isinstance(token, str)
        and bool(token)
        and profile["http_status"] == 200
        and isinstance(profile_json, dict)
        and profile_json.get("username") == username
    )
    return {
        "status": "login-verified" if success else "login-failed",
        "username": username,
        "password": password,
        "credential_origin": "upstream seeded demo account",
        "login_url": public_base + "/docs",
        "api_login_url": public_base + "/api/v1/auth/token",
        "login_http": login["http_status"],
        "token_received": bool(token),
        "business_http": profile["http_status"],
        "business_endpoint": public_base + "/api/v1/auth/me",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("id")
    args = parser.parse_args()
    plans = {item["id"]: item for item in json.loads(PLAN_PATH.read_text(encoding="utf-8"))}
    builds = load_results(BUILD_RESULTS)
    plan = plans[args.id]
    if builds.get(args.id, {}).get("status") != "built":
        raise SystemExit(f"project {args.id} is not build-verified")
    secrets = json.loads(SECRETS_PATH.read_text(encoding="utf-8"))
    runtime_results = load_results(RUNTIME_RESULTS)
    login_results = load_results(LOGIN_RESULTS)
    started = time.monotonic()
    try:
        prepare_runtime(plan, secrets)
        build_result = builds[args.id]
        backend_type = (plan.get("backend") or {}).get("type")
        built_backend_type = (build_result.get("backend") or {}).get("type")
        if built_backend_type == "java-war":
            runtime = start_java_war(plan, secrets, build_result)
        elif backend_type == "java-spring":
            runtime = start_java(plan, secrets, build_result)
        elif backend_type in {"python-auto", "python-django"}:
            runtime = start_python(plan, secrets)
        elif built_backend_type == "dotnet":
            runtime = start_dotnet(plan, secrets, build_result)
        elif built_backend_type == "static-only":
            runtime = start_static(plan)
        else:
            raise RuntimeError(f"unsupported runtime backend: {backend_type or 'none'}")
        local_entry = f"http://127.0.0.1:{plan['assigned_port']}/"
        request_auth_result = None
        if plan["id"] == "ec095":
            request_auth_result = verify_ec095_request_auth(plan)
            http = {
                **request_auth_result["http_response"],
                "path": "/api/stats",
            }
        else:
            http = wait_entry(
                local_entry,
                seconds=180,
                api_container=str(runtime.get("api_container") or ""),
            )
        # A static gateway can return 200 before its API process finishes
        # booting. Require the backend to remain alive and the verified entry
        # to remain reachable after a short settling window before recording a
        # successful runtime result.
        api_container = str(runtime.get("api_container") or "")
        if http["http_status"] == 200 and api_container:
            # ec163 is a large Java 8 monolith whose complete Spring context
            # takes roughly 65-70 seconds even after its frontend is already
            # serving. Poll in short intervals so a late bean failure cannot
            # be recorded as successful.
            stability_seconds = 75 if plan["id"] == "ec163" else 20
            deadline = time.monotonic() + stability_seconds
            state = run(
                ["docker", "inspect", "--format", "{{.State.Running}}", api_container],
                timeout=10,
            )
            while (
                time.monotonic() < deadline
                and state.returncode == 0
                and state.stdout.strip().lower() == "true"
            ):
                time.sleep(min(5, max(0.1, deadline - time.monotonic())))
                state = run(
                    ["docker", "inspect", "--format", "{{.State.Running}}", api_container],
                    timeout=10,
                )
            if state.returncode != 0 or state.stdout.strip().lower() != "true":
                http = {
                    **http,
                    "http_status": 0,
                    "error": f"API container exited during stability check: {api_container}",
                }
            else:
                verified_path = str(http.get("path") or "/")
                stable_http = http_request(
                    local_entry.rstrip("/") + "/" + verified_path.lstrip("/"),
                    timeout=10,
                )
                stable_http["path"] = verified_path
                http = stable_http
        containers = run(
            [
                "docker",
                "ps",
                "--filter",
                f"label=com.kxb.project={plan['id']}",
                "--format",
                "{{.Names}}|{{.Status}}|{{.Ports}}",
            ]
        ).stdout.strip().splitlines()
        runtime_status = "http-verified" if http["http_status"] == 200 else "http-failed"
        if (plan["id"] == "ec104" or built_backend_type == "static-only") and http["http_status"] == 200:
            runtime_status = "display-only"
        runtime_result = {
            "id": plan["id"],
            "status": runtime_status,
            "entry_url": runtime["entry_url"],
            "verified_path": http.get("path", "/"),
            "http_status": http["http_status"],
            "http_error": http["error"],
            "containers": containers,
            "elapsed_seconds": round(time.monotonic() - started, 2),
        }
        if plan["id"] == "ec002" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec002(plan, secrets)}
        elif plan["id"] == "ec082" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec082(plan, secrets)}
        elif plan["id"] == "ec006" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec006(plan, secrets)}
        elif plan["id"] == "ec008" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec008(plan, secrets)}
        elif plan["id"] == "ec042" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec042(plan, secrets)}
        elif plan["id"] == "ec043" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec043_backend(plan)}
        elif plan["id"] == "ec087" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec087(plan, secrets)}
        elif plan["id"] == "ec069" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec069(plan, secrets)}
        elif plan["id"] == "ec095" and request_auth_result is not None:
            login_result = {
                "id": plan["id"],
                **{key: value for key, value in request_auth_result.items() if key != "http_response"},
            }
        elif plan["id"] == "ec092" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec092(plan, secrets)}
        elif plan["id"] == "ec097" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec097(plan, secrets)}
        elif plan["id"] == "ec166" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec166(plan)}
        elif plan["id"] == "ec016" and http["http_status"] == 200:
            login_result = {"id": plan["id"], **verify_ec016(plan, secrets)}
        else:
            login_result = {"id": plan["id"], "status": "not-implemented"}
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        runtime_result = {"id": plan["id"], "status": "run-failed", "error": str(exc)[-2400:]}
        login_result = {"id": plan["id"], "status": "not-tested"}
    runtime_results[plan["id"]] = runtime_result
    login_results[plan["id"]] = login_result
    save_results(RUNTIME_RESULTS, runtime_results)
    save_results(LOGIN_RESULTS, login_results, private=True)
    print(json.dumps(runtime_result, ensure_ascii=False), flush=True)
    print(json.dumps({key: value for key, value in login_result.items() if key != "password"}, ensure_ascii=False), flush=True)
    # Runtime reachability and application-login verification are separate
    # acceptance dimensions.  Most projects do not yet have a project-specific
    # login verifier, so an HTTP-verified application must not be reported to
    # callers as a failed runtime merely because login status is
    # ``not-implemented``.
    return 0 if runtime_result.get("status") in {"http-verified", "display-only"} else 2


if __name__ == "__main__":
    raise SystemExit(main())
