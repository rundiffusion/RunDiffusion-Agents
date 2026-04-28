#!/usr/bin/env python3
"""Patch Hermes WebUI for the in-container RunDiffusion gateway runtime."""

from __future__ import annotations

import re
import sys
from pathlib import Path


STATIC_SUFFIXES = {".css", ".html", ".js", ".mjs"}
ROOT_ROUTE_PATTERN = re.compile(
    r"(?P<quote>[\"'`])/(?P<route>api|health|login|logout|onboarding|static)(?P<suffix>[/\?\"'`])"
)
THINKING_AFTER_STREAM_PATCH = (
    "    // RunDiffusion patch: appendThinking() is guarded on S.activeStreamId,\n"
    "    // so the earlier pre-start call is a no-op until the stream id exists.\n"
    "    appendThinking();\n"
)
SERVICE_WORKER_CACHE_PATCH = "const CACHE_NAME = 'hermes-shell-__CACHE_VERSION__-rundiffusion-v1';"


def patch_service_worker(updated: str) -> str:
    if SERVICE_WORKER_CACHE_PATCH in updated:
        return updated

    old_cache_name = "const CACHE_NAME = 'hermes-shell-__CACHE_VERSION__';"
    if old_cache_name not in updated:
        raise SystemExit("Could not locate Hermes WebUI service worker cache name")
    updated = updated.replace(old_cache_name, SERVICE_WORKER_CACHE_PATCH, 1)

    old_api_bypass = (
        "  if (\n"
        "    url.pathname.startsWith('api/') ||\n"
        "    url.pathname.includes('/stream') ||\n"
        "    url.pathname.startsWith('health')\n"
        "  ) {\n"
        "    return; // let browser handle normally\n"
        "  }\n"
    )
    new_api_bypass = (
        "  const scopePath = new URL(self.registration.scope).pathname;\n"
        "  let scopedPath = url.pathname;\n"
        "  if (scopePath && scopedPath.startsWith(scopePath)) {\n"
        "    scopedPath = scopedPath.slice(scopePath.length);\n"
        "  }\n"
        "  scopedPath = scopedPath.replace(/^\\/+/, '');\n\n"
        "  if (\n"
        "    scopedPath.startsWith('api/') ||\n"
        "    scopedPath === 'health' ||\n"
        "    scopedPath.startsWith('health/') ||\n"
        "    scopedPath === 'stream' ||\n"
        "    scopedPath.includes('/stream')\n"
        "  ) {\n"
        "    return; // let browser handle normally\n"
        "  }\n"
    )
    if old_api_bypass not in updated:
        raise SystemExit("Could not locate Hermes WebUI service worker API bypass block")
    updated = updated.replace(old_api_bypass, new_api_bypass, 1)

    old_shell_cache = (
        "  // Shell assets: cache-first\n"
        "  event.respondWith(\n"
    )
    new_shell_cache = (
        "  // Shell assets: cache-first\n"
        "  const shellAssetUrls = new Set(\n"
        "    SHELL_ASSETS.map((asset) => new URL(asset, self.registration.scope).href)\n"
        "  );\n"
        "  if (!shellAssetUrls.has(event.request.url)) {\n"
        "    return;\n"
        "  }\n\n"
        "  event.respondWith(\n"
    )
    if old_shell_cache not in updated:
        raise SystemExit("Could not locate Hermes WebUI service worker shell cache block")
    updated = updated.replace(old_shell_cache, new_shell_cache, 1)

    return updated


def patch_python_compat(repo_root: Path) -> list[Path]:
    streaming_path = repo_root / "api" / "streaming.py"
    if not streaming_path.is_file():
        raise SystemExit(f"Hermes WebUI streaming module not found: {streaming_path}")
    config_path = repo_root / "api" / "config.py"
    if not config_path.is_file():
        raise SystemExit(f"Hermes WebUI config module not found: {config_path}")

    original = streaming_path.read_text(encoding="utf-8")
    updated = original

    agent_filter_marker = "            # Pin Honcho memory sessions to the stable WebUI session ID.\n"
    agent_filter_patch = (
        "            # Filter constructor kwargs against the installed Hermes Agent API.\n"
        "            # v0.50.236 of hermes-webui can be newer than the pinned\n"
        "            # hermes-agent backend in this gateway image, so runtime-only\n"
        "            # WebUI kwargs such as stream_delta_callback must be skipped\n"
        "            # when the backend does not accept them.\n"
        "            _agent_kwargs = {\n"
        "                _key: _value\n"
        "                for _key, _value in _agent_kwargs.items()\n"
        "                if _key in _agent_params\n"
        "            }\n\n"
    )
    if agent_filter_patch not in updated:
        if agent_filter_marker not in updated:
            raise SystemExit("Could not locate Hermes WebUI agent kwargs insertion point")
        updated = updated.replace(agent_filter_marker, agent_filter_patch + agent_filter_marker, 1)

    old_run_call = (
        "            result = agent.run_conversation(\n"
        "                user_message=workspace_ctx + msg_text,\n"
        "                system_message=workspace_system_msg,\n"
        "                conversation_history=_sanitize_messages_for_api(s.messages),\n"
        "                task_id=session_id,\n"
        "                persist_user_message=msg_text,\n"
        "            )\n"
    )
    new_run_call = (
        "            _run_kwargs = dict(\n"
        "                user_message=workspace_ctx + msg_text,\n"
        "                system_message=workspace_system_msg,\n"
        "                conversation_history=_sanitize_messages_for_api(s.messages),\n"
        "                task_id=session_id,\n"
        "            )\n"
        "            try:\n"
        "                _run_params = set(_inspect.signature(agent.run_conversation).parameters)\n"
        "                if 'persist_user_message' in _run_params:\n"
        "                    _run_kwargs['persist_user_message'] = msg_text\n"
        "            except Exception:\n"
        "                pass\n"
        "            result = agent.run_conversation(**_run_kwargs)\n"
    )
    if new_run_call not in updated:
        if old_run_call not in updated:
            raise SystemExit("Could not locate Hermes WebUI run_conversation call")
        updated = updated.replace(old_run_call, new_run_call, 1)

    changed = []
    if updated != original:
        streaming_path.write_text(updated, encoding="utf-8")
        changed.append(streaming_path)

    config_original = config_path.read_text(encoding="utf-8")
    config_updated = config_original
    old_provider_block = (
        "    if isinstance(model_cfg, dict):\n"
        "        config_provider = model_cfg.get(\"provider\")\n"
        "        config_base_url = model_cfg.get(\"base_url\")\n"
    )
    new_provider_block = (
        "    if isinstance(model_cfg, dict):\n"
        "        config_provider = model_cfg.get(\"provider\")\n"
        "        config_base_url = model_cfg.get(\"base_url\")\n\n"
        "    env_provider = (\n"
        "        os.getenv(\"HERMES_WEBUI_INFERENCE_PROVIDER\")\n"
        "        or os.getenv(\"HERMES_INFERENCE_PROVIDER\")\n"
        "        or \"\"\n"
        "    ).strip()\n"
        "    if env_provider:\n"
        "        config_provider = env_provider\n"
        "        env_base_url = (\n"
        "            os.getenv(\"HERMES_OPENAI_BASE_URL\")\n"
        "            or os.getenv(\"OPENAI_BASE_URL\")\n"
        "            or \"\"\n"
        "        ).strip()\n"
        "        if env_base_url:\n"
        "            config_base_url = env_base_url\n"
    )
    if "HERMES_WEBUI_INFERENCE_PROVIDER" not in config_updated:
        if old_provider_block not in config_updated:
            raise SystemExit("Could not locate Hermes WebUI model provider config block")
        config_updated = config_updated.replace(old_provider_block, new_provider_block, 1)

    if config_updated != config_original:
        config_path.write_text(config_updated, encoding="utf-8")
        changed.append(config_path)

    return changed


def patch_static_assets(repo_root: Path) -> list[Path]:
    static_root = repo_root / "static"
    if not static_root.is_dir():
        raise SystemExit(f"Hermes WebUI static directory not found: {static_root}")

    changed: list[Path] = []
    for asset_path in sorted(static_root.rglob("*")):
        if not asset_path.is_file() or asset_path.suffix not in STATIC_SUFFIXES:
            continue

        original = asset_path.read_text(encoding="utf-8")
        updated = ROOT_ROUTE_PATTERN.sub(
            lambda match: f"{match.group('quote')}{match.group('route')}{match.group('suffix')}",
            original,
        )

        if asset_path.name == "index.html" and "<head>" in updated and "<base " not in updated:
            updated = updated.replace("<head>", '<head><base href="./">', 1)

        if asset_path.name == "messages.js" and THINKING_AFTER_STREAM_PATCH not in updated:
            old = "    S.activeStreamId = streamId;\n    if(S.session&&S.session.session_id===activeSid){\n"
            new = f"    S.activeStreamId = streamId;\n{THINKING_AFTER_STREAM_PATCH}    if(S.session&&S.session.session_id===activeSid){{\n"
            if old not in updated:
                raise SystemExit("Could not locate Hermes WebUI stream activation block")
            updated = updated.replace(old, new, 1)

        if asset_path.name == "sw.js":
            updated = patch_service_worker(updated)

        if updated != original:
            asset_path.write_text(updated, encoding="utf-8")
            changed.append(asset_path)

    return changed


def main() -> None:
    repo_root = Path(sys.argv[1] if len(sys.argv) > 1 else "/opt/hermes-webui")
    changed = patch_static_assets(repo_root) + patch_python_compat(repo_root)
    print(f"Patched {len(changed)} Hermes WebUI asset(s) for gateway compatibility.")


if __name__ == "__main__":
    main()
