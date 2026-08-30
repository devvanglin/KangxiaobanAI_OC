from __future__ import annotations

import csv
import html
import json
from pathlib import Path
from typing import Any


ROOT = Path("/opt/eldercare100")
STATE = ROOT / "state"
PRIVATE = ROOT / "private"
REPORTS = ROOT / "reports"


def load(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def keyed(path: Path) -> dict[str, dict[str, Any]]:
    return {str(item.get("id")): item for item in load(path, []) if item.get("id")}


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    manifest = load(STATE / "canonical-100.json", [])
    plans = keyed(STATE / "build-plan.json")
    builds = keyed(STATE / "build-results.json")
    runtimes = keyed(STATE / "runtime-results.json")
    logins = keyed(PRIVATE / "login-results.json")
    secrets = load(PRIVATE / "secrets.json", {})
    source_rows = load(STATE / "remote-source-results.json", [])
    source_ok = {str(item.get("id")) for item in source_rows if item.get("status") in {"cloned-verified", "already-present"}}

    rows = []
    for project in manifest:
        project_id = str(project["id"])
        plan = plans.get(project_id, {})
        build = builds.get(project_id, {})
        runtime = runtimes.get(project_id, {})
        login = logins.get(project_id, {})
        candidates = plan.get("credential_candidates") or []
        username = str(login.get("username") or (candidates[0].get("username") if candidates else ""))
        password_secret_key = str(login.get("password_secret_key") or "")
        password = str(
            login.get("password")
            or (secrets.get(password_secret_key) if password_secret_key else "")
            or (candidates[0].get("password") if candidates else "")
        )
        port = int(plan.get("assigned_port") or (18000 + int(project_id[2:])))
        rows.append(
            {
                "id": project_id,
                "project": project["primary_full_name"],
                "upstream": project.get("primary_url") or "",
                "source_status": "cloned-verified" if project_id in source_ok else "missing-or-failed",
                "build_status": build.get("status") or "not-tested",
                "http_status": runtime.get("status") or "not-tested",
                "http_code": runtime.get("http_status") or "",
                "original_login_status": login.get("status") or "not-tested",
                "username": username,
                "password": password,
                "portal_detail": f"http://127.0.0.1:18000/project/{project_id}",
                "display_url": f"http://127.0.0.1:18000/display/{project_id}/",
                "real_app_url": f"http://127.0.0.1:{port}/",
                "build_error": str(build.get("error") or "")[-1000:],
                "runtime_error": str(runtime.get("http_error") or runtime.get("error") or "")[-1000:],
            }
        )

    public_rows = [
        {**row, "password": "见私有凭据文档" if row.get("password") else ""}
        for row in rows
    ]
    (REPORTS / "deployment-acceptance.json").write_text(
        json.dumps(public_rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    with (REPORTS / "deployment-acceptance.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(public_rows[0]) if public_rows else [])
        writer.writeheader()
        writer.writerows(public_rows)

    table_rows = "".join(
        "<tr>"
        + "".join(
            f"<td>{html.escape(str(row[key]))}</td>"
            for key in ("id", "project", "source_status", "build_status", "http_status", "http_code", "original_login_status", "username", "password")
        )
        + f'<td><a href="{html.escape(row["portal_detail"])}">详情</a></td>'
        + "</tr>"
        for row in public_rows
    )
    limitations = """
<section><h2>验收边界与部署说明</h2><ul>
<li>ec030：服务器部署禁用了摄像头/CV 初始化；Web 与数据库入口可用，不代表摄像头链路已验证。</li>
<li>ec054：部署副本已清空上游硬编码第三方 AI/OCR 密钥；仓库所有者仍需轮换原密钥。</li>
<li>ec069：数据库结构依据上游实体生成，并非上游官方 SQL；登录与受 Token 保护的业务接口已验证。</li>
<li>ec070/ec119/ec135：Activiti 使用依赖包内官方 MySQL 建表 SQL；OSS 上传/删除未使用真实第三方凭据验证。</li>
<li>ec087：上游快照缺失全部 MVC 控制器，部署补齐了登录与后台壳控制器，凭据来源标记为 deployment completion。</li>
<li>ec091：使用 Redis Stack；启动期 Embedding 由本地零向量兼容服务满足，真实 AI/RAG 效果未验证。</li>
<li>ec095：上游没有账号密码登录，已验证其签名请求加角色头鉴权。</li>
<li>ec104：上游是 Qt/摄像头桌面 GUI，仅以 display-only 展示模式提供 HTTP 访问，不计入 Web 业务入口验证。</li>
<li>ec119：阿里云 IoT AMQP 消费端在无真实凭据环境中禁用；Swagger 文档入口已验证。</li>
<li>ec115 克隆超时；ec133/ec148/ec151 上游需要认证或为占位地址，源码状态保持 missing-or-failed。</li>
<li>ec154：使用部署侧私有随机派生 JWT 签名值启动；仓库快照缺少种子数据库引用的图片文件，因此部署禁用了启动期图片完整性阻断，相关图片展示不在验收范围。</li>
<li>ec156：Web/API 入口已验证；计算机视觉模型、摄像头、机器人和真实硬件链路未验证。</li>
<li>ec157：本地部署使用禁用态 OSS 配置满足启动检查；未使用真实阿里云凭据，上传和删除能力未验证。</li>
<li>ec158：上游源码缺少控制器引用的整个 com.sm.graduation.out Java 包，当前快照无法编译。</li>
<li>ec160：上游为 Next.js + Prisma 动态服务，没有可独立发布的静态产物；当前 Alpine/Prisma 运行链未通过，因此未冒充静态部署。</li>
<li>ec161/ec162：上游只有可发布前端，按 display-only 展示模式验收，不计入后端业务入口验证。</li>
<li>ec163：上游快照的 application 配置文件只剩许可证头，部署侧补齐本地数据库、Redis、Token、XSS 与禁用态第三方配置；OSS/STS/微信能力未使用真实凭据验证。两份重复/增量 SQL 未重复执行，使用已成功导入的主业务结构。</li>
<li>ec166：使用本地 SQLite 并禁用无真实 broker 的 MQTT 初始化；OAuth2 Token 与受保护用户接口已验证。</li>
</ul></section>
"""
    report_html = f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>养老项目部署验收</title>
<style>body{{font-family:"Segoe UI","Microsoft YaHei",sans-serif;padding:24px;color:#17233a}}table{{border-collapse:collapse;width:100%;font-size:13px}}th,td{{border:1px solid #d9e1ec;padding:7px;vertical-align:top}}th{{background:#eef4fb;position:sticky;top:0}}.summary{{padding:14px;background:#eef6ff;border-radius:10px;margin-bottom:18px}}</style></head><body>
<h1>智慧养老开源项目部署验收</h1><div class="summary">总数 {len(rows)}；源码校验 {sum(r['source_status']=='cloned-verified' for r in rows)}；构建成功 {sum(r['build_status']=='built' for r in rows)}；HTTP 验证 {sum(r['http_status']=='http-verified' for r in rows)}；应用登录验证 {sum(r['original_login_status']=='login-verified' for r in rows)}；桌面/展示模式 {sum(r['http_status']=='display-only' for r in rows)}。</div>
{limitations}<table><tr><th>ID</th><th>项目</th><th>源码</th><th>构建</th><th>HTTP</th><th>HTTP码</th><th>应用登录</th><th>账号</th><th>密码</th><th>详情</th></tr>{table_rows}</table></body></html>"""
    (REPORTS / "deployment-acceptance.html").write_text(report_html, encoding="utf-8")

    portal_user = str(secrets.get("portal_username") or "")
    portal_password = str(secrets.get("portal_password") or "")
    lines = [
        "# 智慧养老项目访问账号与密码",
        "",
        "## 统一门户",
        "",
        "- 地址：http://127.0.0.1:18000/",
        f"- 账号：{portal_user}",
        f"- 密码：{portal_password}",
        "- 说明：统一门户账号已通过真实表单登录验证。各项目只有状态为 login-verified 才算真实表单或 API 登录成功；request-auth-verified 表示上游使用签名请求而非账号密码。",
        "- 安全：公开验收 HTML/CSV/JSON 不再写入明文密码；完整账号密码仅保存在本文件。",
        "",
        "## 各项目",
        "",
        "| ID | 项目 | 应用登录状态 | 账号 | 密码 | 详情 |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        values = [str(row[key]).replace("|", "\\|") for key in ("id", "project", "original_login_status", "username", "password")]
        lines.append(f"| {' | '.join(values)} | {row['portal_detail']} |")
    private_report = PRIVATE / "ACCESS-CREDENTIALS.md"
    private_report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    private_report.chmod(0o600)

    print(f"REPORT_PROJECTS={len(rows)}")
    print(f"SOURCE_VERIFIED={sum(r['source_status']=='cloned-verified' for r in rows)}")
    print(f"BUILD_VERIFIED={sum(r['build_status']=='built' for r in rows)}")
    print(f"HTTP_VERIFIED={sum(r['http_status']=='http-verified' for r in rows)}")
    print(f"LOGIN_VERIFIED={sum(r['original_login_status']=='login-verified' for r in rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
