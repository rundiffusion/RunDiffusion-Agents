#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import stat
from pathlib import Path

SENSITIVE_KEY_RE = re.compile(r"(KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTHKEY)", re.IGNORECASE)
OPTIONAL_BLANK_KEYS = {
    "PUBLIC_URL_SCHEME",
    "GATEWAY_IMAGE_TAG",
    "DOCKER_BUILD_CONTEXT",
    "DOCKER_BUILDER",
    "DOCKER_BUILD_PLATFORM",
    "BACKUP_ROOT",
    "RELEASE_ROOT",
}
CLOUDFLARE_REQUIRED_KEYS = {
    "CLOUDFLARE_TUNNEL_ID",
    "CLOUDFLARE_TUNNEL_CREDENTIALS_FILE",
}


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def display_env_value(key: str, value: str) -> str:
    if value not in ("", "<missing>") and SENSITIVE_KEY_RE.search(key):
        return "<redacted>"
    return value


def resolve_repo_root(explicit_repo_root: str | None) -> Path:
    if explicit_repo_root:
        return Path(explicit_repo_root).resolve()
    return Path(__file__).resolve().parents[3]


def path_is_inside_repo(path_value: str, repo_root: Path) -> bool | None:
    if not path_value or "$" in path_value:
        return None

    candidate = Path(path_value).expanduser()
    if not candidate.is_absolute():
        candidate = repo_root / candidate

    try:
        candidate.resolve().relative_to(repo_root)
    except ValueError:
        return False

    return True


def expand_value(value: str, values: dict[str, str]) -> str:
    expanded = value
    for key in ("DATA_ROOT", "TENANT_ENV_ROOT", "BASE_DOMAIN", "COMPOSE_PROJECT_NAME"):
        expanded = expanded.replace(f"${{{key}}}", values.get(key, ""))
    return expanded


def release_root(values: dict[str, str]) -> Path | None:
    configured = values.get("RELEASE_ROOT", "").strip()
    if configured:
        return Path(configured)
    data_root = values.get("DATA_ROOT", "").strip()
    if data_root:
        return Path(data_root) / "releases"
    return None


def parse_tenant_registry(registry_path: Path, values: dict[str, str]) -> list[dict[str, str]]:
    if not registry_path.is_file():
        return []

    tenants: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for raw_line in registry_path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if stripped.startswith("- slug:"):
            if current:
                tenants.append(current)
            current = {"slug": stripped.split(":", 1)[1].strip().strip('"')}
            continue
        if current is None or ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        key = key.strip()
        if key in {"display_name", "hostname", "project_name", "data_root", "env_file"}:
            current[key] = expand_value(value.strip().strip('"'), values)
    if current:
        tenants.append(current)
    return tenants


def file_mode(path: Path) -> str:
    return oct(stat.S_IMODE(path.stat().st_mode))


def collect_tenant_state_warnings(repo_root: Path, actual_values: dict[str, str]) -> tuple[list[str], list[str]]:
    tenant_warnings: list[str] = []
    orphan_warnings: list[str] = []
    registry_path = repo_root / "deploy" / "tenants" / "tenants.yml"
    tenants = parse_tenant_registry(registry_path, actual_values)
    registry_slugs = {tenant["slug"] for tenant in tenants if tenant.get("slug")}

    for tenant in tenants:
        slug = tenant.get("slug", "<unknown>")
        env_file = Path(tenant.get("env_file", ""))
        if not env_file.is_file():
            tenant_warnings.append(f"{slug} tenant env file is missing: {env_file}")
            continue
        mode = file_mode(env_file)
        if mode != "0o600":
            tenant_warnings.append(f"{slug} tenant env file mode is {mode}, expected 0o600: {env_file}")

    tenant_env_root_value = actual_values.get("TENANT_ENV_ROOT", "").strip()
    if tenant_env_root_value:
        tenant_env_root = Path(tenant_env_root_value)
        if tenant_env_root.is_dir():
            actual_env_slugs = {path.stem for path in tenant_env_root.glob("*.env")}
            orphan_env_slugs = sorted(actual_env_slugs - registry_slugs)
            if orphan_env_slugs:
                orphan_warnings.append("orphan tenant env files: " + ", ".join(orphan_env_slugs))

            managed_root = tenant_env_root / "managed"
            if managed_root.is_dir():
                actual_managed_slugs = {path.stem for path in managed_root.glob("*.env")}
                orphan_managed_slugs = sorted(actual_managed_slugs - registry_slugs)
                if orphan_managed_slugs:
                    orphan_warnings.append("orphan managed env files: " + ", ".join(orphan_managed_slugs))

    releases = release_root(actual_values)
    if releases and releases.is_dir():
        release_slugs = {path.name for path in releases.iterdir() if path.is_dir() and path.name != "shared"}
        orphan_release_slugs = sorted(release_slugs - registry_slugs)
        if orphan_release_slugs:
            orphan_warnings.append("orphan release metadata: " + ", ".join(orphan_release_slugs))

    return tenant_warnings, orphan_warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate root .env against .env.example")
    parser.add_argument("--repo-root", help="Path to the repo root")
    args = parser.parse_args()

    repo_root = resolve_repo_root(args.repo_root)
    env_example_path = repo_root / ".env.example"
    env_path = repo_root / ".env"

    if not env_example_path.is_file():
        raise SystemExit(f"Missing .env.example: {env_example_path}")

    if not env_path.is_file():
        raise SystemExit(f"Missing .env: {env_path}")

    example_values = parse_env_file(env_example_path)
    actual_values = parse_env_file(env_path)
    ingress_mode = actual_values.get("INGRESS_MODE", example_values.get("INGRESS_MODE", "local"))

    missing_keys = [key for key in example_values if key not in actual_values]
    blank_keys = [key for key, value in actual_values.items() if key in example_values and value == ""]
    extra_keys = [key for key in actual_values if key not in example_values]
    optional_blank_keys = set(OPTIONAL_BLANK_KEYS)
    path_warnings: list[str] = []

    if ingress_mode != "cloudflare":
        optional_blank_keys.update(CLOUDFLARE_REQUIRED_KEYS)

    required_blank_keys = [key for key in blank_keys if key not in optional_blank_keys]

    for key in ("DATA_ROOT", "TENANT_ENV_ROOT"):
        value = actual_values.get(key, "")
        inside_repo = path_is_inside_repo(value, repo_root)
        if inside_repo:
            path_warnings.append(f"{key} points inside the git checkout: {value}")

    tenant_warnings, orphan_warnings = collect_tenant_state_warnings(repo_root, actual_values)

    print(f"Repo root: {repo_root}")
    print(f"Root env example: {env_example_path}")
    print(f"Root env: {env_path}")
    print("")

    if missing_keys:
        print("Missing keys in .env:")
        for key in missing_keys:
            print(f"  - {key}")
    else:
        print("Missing keys in .env: none")

    if blank_keys:
        print("Blank keys in .env:")
        for key in blank_keys:
            print(f"  - {key}")
    else:
        print("Blank keys in .env: none")

    if required_blank_keys:
        print("Blank required keys in .env:")
        for key in required_blank_keys:
            print(f"  - {key}")
    else:
        print("Blank required keys in .env: none")

    if extra_keys:
        print("Extra keys in .env:")
        for key in extra_keys:
            print(f"  - {key}")
    else:
        print("Extra keys in .env: none")

    if path_warnings:
        print("Repo-local path warnings:")
        for warning in path_warnings:
            print(f"  - {warning}")
    else:
        print("Repo-local path warnings: none")

    if tenant_warnings:
        print("Tenant env warnings:")
        for warning in tenant_warnings:
            print(f"  - {warning}")
    else:
        print("Tenant env warnings: none")

    if orphan_warnings:
        print("Orphan tenant state warnings:")
        for warning in orphan_warnings:
            print(f"  - {warning}")
    else:
        print("Orphan tenant state warnings: none")

    print("")
    print("Effective root values:")
    for key in example_values:
        actual = actual_values.get(key, "<missing>")
        print(f"  {key}={display_env_value(key, actual)}")

    return 1 if missing_keys or required_blank_keys or path_warnings else 0


if __name__ == "__main__":
    raise SystemExit(main())
