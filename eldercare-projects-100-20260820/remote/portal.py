from __future__ import annotations

import hashlib
import hmac
import html
import json
import mimetypes
import os
import secrets as secrets_module
import subprocess
import sys
import threading
import time
import urllib.parse
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
STATE = ROOT / "state"
PRIVATE = ROOT / "private"
LOGS = ROOT / "logs" / "portal"
MANIFEST = STATE / "canonical-100.json"
PLAN = STATE / "build-plan.json"
BUILD = STATE / "build-results.json"
RUNTIME = STATE / "runtime-results.json"
LOGIN = PRIVATE / "login-results.json"
SOURCE_RESULTS = STATE / "remote-source-results.json"
SECRETS = PRIVATE / "secrets.json"
RUNNER = ROOT / "tools" / "run_project.py"
MAX_ACTIVE_PROJECTS = 12


def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def keyed(path: Path) -> dict[str, dict[str, Any]]:
    return {str(item.get("id")): item for item in load_json(path, []) if item.get("id")}


CONFIG = load_json(SECRETS, {})
PORTAL_USER = str(CONFIG.get("portal_username") or "admin")
PORTAL_PASSWORD = str(CONFIG.get("portal_password") or "")
SESSION_KEY = hashlib.sha256((PORTAL_PASSWORD + "|eldercare153").encode()).digest()
RUNNING_PROCESSES: dict[str, subprocess.Popen[bytes]] = {}
RUNNING_LOCK = threading.Lock()


def session_token(expiry: int) -> str:
    payload = f"{PORTAL_USER}|{expiry}"
    signature = hmac.new(SESSION_KEY, payload.encode(), hashlib.sha256).hexdigest()
    return f"{expiry}.{signature}"


def valid_session(value: str) -> bool:
    try:
        expiry_text, signature = value.split(".", 1)
        expiry = int(expiry_text)
    except (ValueError, TypeError):
        return False
    if expiry < int(time.time()):
        return False
    expected = session_token(expiry).split(".", 1)[1]
    return hmac.compare_digest(signature, expected)


def active_project_ids() -> list[str]:
    completed = subprocess.run(
        ["docker", "ps", "--filter", "label=com.kxb.project", "--format", "{{.Label \"com.kxb.project\"}}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=20,
        check=False,
    )
    return sorted({line.strip() for line in completed.stdout.splitlines() if line.strip()})


def stop_project(project_id: str) -> None:
    found = subprocess.run(
        ["docker", "ps", "-aq", "--filter", f"label=com.kxb.project={project_id}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=20,
        check=False,
    )
    container_ids = found.stdout.split()
    if container_ids:
        subprocess.run(
            ["docker", "rm", "-f", *container_ids],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=60,
            check=False,
        )


def start_project(project_id: str) -> tuple[bool, str]:
    plans = keyed(PLAN)
    builds = keyed(BUILD)
    if project_id not in plans:
        return False, "项目不存在"
    if builds.get(project_id, {}).get("status") != "built":
        return False, "原项目未完成可运行构建；请使用展示入口查看源码与失败记录"
    with RUNNING_LOCK:
        process = RUNNING_PROCESSES.get(project_id)
        if process is not None and process.poll() is None:
            return True, "项目正在启动"
        active = active_project_ids()
        if len(active) >= MAX_ACTIVE_PROJECTS:
            for candidate in active:
                if candidate != project_id:
                    stop_project(candidate)
                    break
        LOGS.mkdir(parents=True, exist_ok=True)
        log_handle = (LOGS / f"{project_id}.log").open("ab")
        process = subprocess.Popen(
            [sys.executable, str(RUNNER), project_id],
            stdout=log_handle,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        RUNNING_PROCESSES[project_id] = process
    return True, "启动任务已提交，通常需要 10 到 180 秒"


def find_readme(project_id: str) -> str:
    source = ROOT / "sources" / project_id
    if not source.is_dir():
        return "源码尚未到位。"
    candidates = []
    for path in source.rglob("*"):
        if path.is_file() and path.name.lower().startswith("readme"):
            try:
                size = path.stat().st_size
            except OSError:
                continue
            if size <= 600_000:
                candidates.append(path)
        if len(candidates) >= 8:
            break
    if not candidates:
        return "仓库没有可读取的 README。"
    try:
        text = candidates[0].read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "README 读取失败。"
    lines = [line.strip("# `\t") for line in text.splitlines() if line.strip()]
    return "\n".join(lines[:28])[:6000]


def project_context(project_id: str) -> dict[str, Any] | None:
    manifest = keyed(MANIFEST)
    plans = keyed(PLAN)
    builds = keyed(BUILD)
    runtimes = keyed(RUNTIME)
    logins = keyed(LOGIN)
    project = manifest.get(project_id)
    if not project:
        return None
    return {
        "project": project,
        "plan": plans.get(project_id, {}),
        "build": builds.get(project_id, {}),
        "runtime": runtimes.get(project_id, {}),
        "login": logins.get(project_id, {}),
        "active": project_id in active_project_ids(),
    }


def page(title: str, body: str, refresh: int = 0) -> bytes:
    refresh_tag = f'<meta http-equiv="refresh" content="{refresh}">' if refresh else ""
    document = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
{refresh_tag}<title>{html.escape(title)}</title><style>
:root{{--bg:#f4f7fb;--card:#fff;--ink:#152238;--muted:#64748b;--blue:#1769e0;--green:#14804a;--red:#c73737;--amber:#a65f00}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font-family:Inter,"Segoe UI","Microsoft YaHei",sans-serif}}
a{{color:var(--blue);text-decoration:none}}header{{position:sticky;top:0;z-index:3;background:#102a4c;color:#fff;padding:16px 28px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 2px 12px #102a4c33}}
header a{{color:#fff}}main{{max-width:1480px;margin:0 auto;padding:24px}}.card{{background:var(--card);border:1px solid #dce5f0;border-radius:16px;padding:20px;box-shadow:0 6px 22px #183a6210}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}}.row{{display:flex;gap:10px;flex-wrap:wrap;align-items:center}}
.pill{{display:inline-block;border-radius:999px;padding:4px 10px;background:#e9eff8;color:#334155;font-size:12px}}.ok{{background:#dff5e9;color:var(--green)}}.bad{{background:#fde8e8;color:var(--red)}}.warn{{background:#fff0d5;color:var(--amber)}}
.button,button{{display:inline-block;border:0;border-radius:10px;background:var(--blue);color:#fff;padding:10px 15px;font-weight:650;cursor:pointer}}.secondary{{background:#e5edf8;color:#16365c}}
h1,h2,h3{{margin-top:0}}pre{{white-space:pre-wrap;word-break:break-word;background:#0e1d30;color:#dbeafe;padding:16px;border-radius:12px;max-height:500px;overflow:auto}}
table{{width:100%;border-collapse:collapse}}th,td{{padding:10px;border-bottom:1px solid #e3eaf3;text-align:left;vertical-align:top}}small,.muted{{color:var(--muted)}}iframe{{width:100%;height:72vh;border:1px solid #dce5f0;border-radius:12px;background:#fff}}
input{{width:100%;padding:12px;border:1px solid #bdcadb;border-radius:10px;margin:6px 0 14px}}.login{{max-width:430px;margin:9vh auto}}
</style></head><body><header><a href="/"><strong>智慧养老开源项目部署中心</strong></a><nav><a href="/">项目清单</a>　<a href="/credentials">账号与验收</a>　<a href="/logout">退出</a></nav></header><main>{body}</main></body></html>"""
    return document.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "Eldercare153Portal/1.0"

    def log_message(self, fmt: str, *args: Any) -> None:
        LOGS.mkdir(parents=True, exist_ok=True)
        with (LOGS / "access.log").open("a", encoding="utf-8") as handle:
            handle.write(f"{self.log_date_time_string()} {self.client_address[0]} {fmt % args}\n")

    def cookie_value(self, name: str) -> str:
        jar = cookies.SimpleCookie(self.headers.get("Cookie", ""))
        return jar[name].value if name in jar else ""

    def authenticated(self) -> bool:
        return valid_session(self.cookie_value("ec_session"))

    def redirect(self, location: str) -> None:
        self.send_response(303)
        self.send_header("Location", location)
        self.end_headers()

    def send_html(self, content: bytes, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def require_auth(self) -> bool:
        if self.authenticated():
            return True
        self.redirect("/login")
        return False

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0") or 0)
        form = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", "replace"))
        if parsed.path == "/login":
            username = form.get("username", [""])[0]
            password = form.get("password", [""])[0]
            if hmac.compare_digest(username, PORTAL_USER) and hmac.compare_digest(password, PORTAL_PASSWORD):
                expiry = int(time.time()) + 12 * 3600
                self.send_response(303)
                self.send_header("Location", "/")
                self.send_header("Set-Cookie", f"ec_session={session_token(expiry)}; Path=/; HttpOnly; SameSite=Lax")
                self.end_headers()
                return
            self.send_html(page("登录失败", '<div class="card login"><h2>登录失败</h2><p>账号或密码不正确。</p><a class="button" href="/login">返回</a></div>'), 401)
            return
        if not self.require_auth():
            return
        if parsed.path.startswith("/api/start/"):
            project_id = parsed.path.rsplit("/", 1)[-1]
            ok, message = start_project(project_id)
            self.redirect(f"/project/{project_id}?message={urllib.parse.quote(message)}")
            return
        if parsed.path.startswith("/api/stop/"):
            project_id = parsed.path.rsplit("/", 1)[-1]
            stop_project(project_id)
            self.redirect(f"/project/{project_id}?message={urllib.parse.quote('项目容器已停止')}")
            return
        self.send_error(404)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/login":
            project_count = len(load_json(MANIFEST, []))
            body = f"""<div class="card login"><h1>智慧养老项目部署中心</h1><p class="muted">统一访问入口，登录后可查看 {project_count} 个仓库的源码、构建、运行及原系统登录验收状态。</p><form method="post"><label>账号</label><input name="username" autocomplete="username" required><label>密码</label><input type="password" name="password" autocomplete="current-password" required><button type="submit">登录</button></form></div>"""
            self.send_html(page("登录", body))
            return
        if parsed.path == "/health":
            payload = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if parsed.path == "/logout":
            self.send_response(303)
            self.send_header("Location", "/login")
            self.send_header("Set-Cookie", "ec_session=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax")
            self.end_headers()
            return
        if not self.require_auth():
            return
        if parsed.path == "/":
            self.dashboard()
            return
        if parsed.path == "/credentials":
            self.credentials_page()
            return
        if parsed.path.startswith("/project/"):
            self.project_page(parsed.path.rsplit("/", 1)[-1], parsed.query)
            return
        if parsed.path.startswith("/display/"):
            parts = parsed.path.split("/", 3)
            project_id = parts[2] if len(parts) > 2 else ""
            relative = parts[3] if len(parts) > 3 else ""
            self.display_file(project_id, relative)
            return
        self.send_error(404)

    def dashboard(self) -> None:
        manifest = load_json(MANIFEST, [])
        builds = keyed(BUILD)
        runtimes = keyed(RUNTIME)
        logins = keyed(LOGIN)
        source_rows = load_json(SOURCE_RESULTS, [])
        source_ok = {str(item.get("id")) for item in source_rows if item.get("status") in {"cloned-verified", "already-present"}}
        built = sum(item.get("status") == "built" for item in builds.values())
        http_ok = sum(item.get("status") == "http-verified" for item in runtimes.values())
        display_only = sum(item.get("status") == "display-only" for item in runtimes.values())
        login_ok = sum(item.get("status") == "login-verified" for item in logins.values())
        cards = []
        for project in manifest:
            project_id = str(project["id"])
            build_status = str(builds.get(project_id, {}).get("status") or "not-tested")
            runtime_status = str(runtimes.get(project_id, {}).get("status") or "not-tested")
            login_status = str(logins.get(project_id, {}).get("status") or "not-tested")
            cards.append(
                f'<article class="card"><div class="row"><span class="pill">{html.escape(project_id)}</span>'
                f'<span class="pill {"ok" if project_id in source_ok else "warn"}">源码 {"OK" if project_id in source_ok else "等待"}</span>'
                f'<span class="pill {"ok" if build_status == "built" else "bad"}">构建 {html.escape(build_status)}</span>'
                f'<span class="pill {"ok" if runtime_status == "http-verified" else "warn"}">HTTP {html.escape(runtime_status)}</span></div>'
                f'<h3 style="margin-top:14px">{html.escape(str(project["primary_full_name"]))}</h3>'
                f'<p class="muted">原系统登录：{html.escape(login_status)}</p>'
                f'<a class="button" href="/project/{project_id}">查看与启动</a></article>'
            )
        body = (
            f'<div class="card" style="margin-bottom:18px"><h1>{len(manifest)} 个养老开源仓库</h1>'
            f'<div class="row"><span class="pill ok">清单 {len(manifest)}</span><span class="pill">已构建 {built}</span>'
            f'<span class="pill">HTTP 验证 {http_ok}</span><span class="pill">展示模式 {display_only}</span>'
            f'<span class="pill">原系统登录验证 {login_ok}</span>'
            f'<span class="pill">当前运行 {len(active_project_ids())}/{MAX_ACTIVE_PROJECTS}</span></div>'
            f'<p class="muted">展示入口始终可访问；真实业务容器按需启动，避免 {len(manifest)} 套重型服务同时耗尽内存。状态会随构建和验收持续更新。</p></div>'
            '<section class="grid">' + "".join(cards) + "</section>"
        )
        self.send_html(page("项目清单", body, refresh=90))

    def project_page(self, project_id: str, query: str) -> None:
        context = project_context(project_id)
        if context is None:
            self.send_error(404)
            return
        project, plan = context["project"], context["plan"]
        build, runtime, login = context["build"], context["runtime"], context["login"]
        host = self.headers.get("Host", "192.168.100.10").split(":", 1)[0]
        port = int(plan.get("assigned_port") or (18000 + int(project_id[2:])))
        query_values = urllib.parse.parse_qs(query)
        message = query_values.get("message", [""])[0]
        candidates = plan.get("credential_candidates") or []
        source_root = ROOT / "sources" / project_id
        source_verified = any(source_root.rglob(".source.json")) if source_root.is_dir() else False
        source_label = "已拉取并校验" if source_verified else (
            "仅有本地占位展示，上游当前要求认证或不可公开克隆"
            if (source_root / "showcase.html").is_file()
            else "等待或拉取失败"
        )
        candidate_rows = "".join(
            f'<tr><td>{html.escape(str(item.get("username", "")))}</td><td>{html.escape(str(item.get("password", "")))}</td><td>{html.escape(str(item.get("source", "")))}</td></tr>'
            for item in candidates
        ) or '<tr><td colspan="3">README 中未识别到可靠账号密码</td></tr>'
        built = build.get("status") == "built"
        body = f"""<div class="card">
<div class="row"><span class="pill">{html.escape(project_id)}</span><span class="pill">{html.escape(str(project.get('platforms', [])))}</span></div>
<h1>{html.escape(str(project['primary_full_name']))}</h1>
{f'<p class="warn pill">{html.escape(message)}</p>' if message else ''}
<p><a href="{html.escape(str(project.get('primary_url') or '#'))}" target="_blank" rel="noreferrer">上游源码地址</a></p>
<div class="row"><a class="button secondary" href="/display/{project_id}/">展示入口</a>
<form method="post" action="/api/start/{project_id}"><button {'disabled' if not built else ''}>启动真实业务系统</button></form>
<a class="button" href="http://{html.escape(host)}:{port}/" target="_blank">打开真实业务端口</a>
<form method="post" action="/api/stop/{project_id}"><button class="secondary">停止业务容器</button></form></div></div>
<div class="grid" style="margin-top:18px"><section class="card"><h2>验收状态</h2><table>
<tr><th>源码</th><td>{source_label}</td></tr>
<tr><th>构建</th><td>{html.escape(str(build.get('status') or 'not-tested'))}</td></tr>
<tr><th>HTTP</th><td>{html.escape(str(runtime.get('status') or 'not-tested'))} {html.escape(str(runtime.get('http_status') or ''))}</td></tr>
<tr><th>原系统登录</th><td>{html.escape(str(login.get('status') or 'not-tested'))}</td></tr>
<tr><th>当前容器</th><td>{'运行中' if context['active'] else '未运行'}</td></tr></table></section>
<section class="card"><h2>账号候选</h2><table><tr><th>账号</th><th>密码</th><th>来源</th></tr>{candidate_rows}</table>
<p class="muted">候选值来自上游 README，只有登录接口实际成功后才会标为 login-verified。</p></section></div>
<section class="card" style="margin-top:18px"><h2>项目说明</h2><pre>{html.escape(find_readme(project_id))}</pre></section>
<section class="card" style="margin-top:18px"><h2>构建/运行摘要</h2><pre>{html.escape(json.dumps({'build': build, 'runtime': runtime, 'login': {k:v for k,v in login.items() if k != 'password'}}, ensure_ascii=False, indent=2)[-12000:])}</pre></section>"""
        self.send_html(page(str(project["primary_full_name"]), body, refresh=45 if message else 0))

    def credentials_page(self) -> None:
        manifest = keyed(MANIFEST)
        plans = keyed(PLAN)
        logins = keyed(LOGIN)
        rows = []
        for project_id in sorted(manifest):
            project = manifest[project_id]
            login = logins.get(project_id, {})
            candidates = plans.get(project_id, {}).get("credential_candidates") or []
            username = str(login.get("username") or (candidates[0].get("username") if candidates else ""))
            password = str(login.get("password") or (candidates[0].get("password") if candidates else ""))
            rows.append(
                f'<tr><td><a href="/project/{project_id}">{project_id}</a></td><td>{html.escape(str(project["primary_full_name"]))}</td>'
                f'<td>{html.escape(str(login.get("status") or "not-tested"))}</td><td>{html.escape(username)}</td><td>{html.escape(password)}</td></tr>'
            )
        body = '<div class="card"><h1>原系统登录账号与验收</h1><p class="muted">空白表示上游没有给出账号；not-tested/not-implemented 不能视为已验证登录。统一门户本身已经要求登录。</p><table><tr><th>ID</th><th>项目</th><th>状态</th><th>账号</th><th>密码</th></tr>' + "".join(rows) + '</table></div>'
        self.send_html(page("账号与验收", body))

    def display_file(self, project_id: str, relative: str) -> None:
        build = keyed(BUILD).get(project_id, {})
        frontend = build.get("frontend") or {}
        web = Path(str(frontend.get("web") or ""))
        if web.is_dir():
            requested = (web / relative).resolve() if relative else (web / "index.html").resolve()
            try:
                requested.relative_to(web.resolve())
            except ValueError:
                self.send_error(403)
                return
            if not requested.is_file():
                requested = web / "index.html"
            if requested.is_file():
                data = requested.read_bytes()
                mime = mimetypes.guess_type(requested.name)[0] or "application/octet-stream"
                self.send_response(200)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
        showcase = ROOT / "sources" / project_id / "showcase.html"
        if showcase.is_file() and not relative:
            data = showcase.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        context = project_context(project_id)
        if context is None:
            self.send_error(404)
            return
        project = context["project"]
        body = f'<div class="card"><span class="pill">{html.escape(project_id)}</span><h1>{html.escape(str(project["primary_full_name"]))}</h1><p>该仓库暂未产生可独立运行的 Web 前端，以下展示源码说明和真实验收状态。</p><pre>{html.escape(find_readme(project_id))}</pre><a class="button" href="/project/{project_id}">返回项目详情</a></div>'
        self.send_html(page(f"{project_id} 展示", body))


def main() -> int:
    if not PORTAL_PASSWORD:
        raise RuntimeError("portal password is missing")
    LOGS.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("0.0.0.0", 18000), Handler)
    print("PORTAL_LISTEN=0.0.0.0:18000", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
