from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path


TASK_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = TASK_ROOT.parent
MANIFESTS = TASK_ROOT / "manifests"
OLD_ROOT = WORKSPACE / "elderly-care-repos"


def git_value(repo: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=90,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed for {repo}: {completed.stderr[-800:]}")
    return completed.stdout.strip()


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    current = json.loads((MANIFESTS / "canonical-100.json").read_text(encoding="utf-8"))
    old = json.loads((OLD_ROOT / "selected_100.json").read_text(encoding="utf-8"))
    existing = {item["primary_full_name"].lower() for item in current}
    extra = [item for item in old if item["full_name"].lower() not in existing]
    extra.sort(key=lambda item: (str(item.get("cat") or ""), item["full_name"].lower()))

    canonical = list(current)
    for index, item in enumerate(extra, 101):
        full_name = str(item["full_name"])
        local_dir = OLD_ROOT / "repos" / full_name.replace("/", "__")
        head = git_value(local_dir, "rev-parse", "HEAD")
        tree = git_value(local_dir, "rev-parse", "HEAD^{tree}")
        platform = str(item.get("platform") or "github").lower()
        html_url = str(item.get("html_url") or "")
        clone_url = str(item.get("clone_url") or (html_url.rstrip("/") + ".git"))
        canonical.append(
            {
                "project_key": full_name.lower(),
                "display_name": full_name,
                "primary_full_name": full_name,
                "primary_url": html_url,
                "platforms": [platform],
                "components": [
                    {
                        "full_name": full_name,
                        "html_url": html_url,
                        "clone_url": clone_url,
                        "local_dir": str(local_dir),
                        "git_head": head,
                        "git_tree": tree,
                        "project_type": "legacy-screened",
                        "selection_score": float(item.get("score") or 0),
                        "screened_local_dir": str(local_dir),
                        "clone_status": "cloned",
                        "changed_since_screening": False,
                    }
                ],
                "component_count": 1,
                "has_frontend": False,
                "has_backend": False,
                "has_login_evidence": False,
                "has_database_evidence": False,
                "has_compose": False,
                "has_dockerfile": False,
                "license_status": [str(item.get("license") or "undeclared")],
                "selection_score": float(item.get("score") or 0),
                "screening_status": "legacy-screened",
                "clone_status": "cloned",
                "build_status": "not-tested",
                "http_status": "not-tested",
                "login_status": "not-tested",
                "category": str(item.get("cat") or ""),
                "description": str(item.get("description") or ""),
                "id": f"ec{index:03d}",
            }
        )

    canonical_path = MANIFESTS / "canonical-153.json"
    inventory_path = MANIFESTS / "deployment-inventory-153.json"
    plan_path = MANIFESTS / "build-plan-153.json"
    canonical_path.write_text(json.dumps(canonical, ensure_ascii=False, indent=2), encoding="utf-8")

    inventory_module = load_module(
        "derive_deployment_inventory_153", TASK_ROOT / "tools" / "derive_deployment_inventory.py"
    )
    inventory_module.CANONICAL = canonical_path
    inventory_module.OUTPUT = inventory_path
    inventory_module.main()

    plan_module = load_module("generate_build_plan_153", TASK_ROOT / "tools" / "generate_build_plan.py")
    plan_module.INVENTORY = inventory_path
    plan_module.OUTPUT = plan_path
    plan_module.main()

    print(f"CANONICAL={len(canonical)} EXTRA={len(extra)}")
    print(f"OUTPUT={canonical_path}")
    print(f"OUTPUT={inventory_path}")
    print(f"OUTPUT={plan_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
