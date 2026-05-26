from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import tiktoken
from fastapi import FastAPI, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles


SESSION_ROOT = Path.home() / ".codex" / "sessions"
STATIC_DIR = Path(__file__).parent / "static"
ENCODER = tiktoken.get_encoding("o200k_base")

app = FastAPI(title="Codex Context Window Visualizer")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


def rollout_files() -> list[Path]:
    return sorted(SESSION_ROOT.glob("**/rollout-*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)


def latest_rollout() -> Path | None:
    files = rollout_files()
    return files[0] if files else None


def rollout_id(path: Path) -> str:
    return path.stem.removeprefix("rollout-")


def path_for_session(session_id: str | None) -> Path | None:
    if not session_id or session_id == "latest":
        return latest_rollout()
    for path in rollout_files():
        if rollout_id(path) == session_id or path.name == session_id:
            return path
    return None


def session_meta(path: Path) -> dict[str, Any]:
    meta: dict[str, Any] = {}
    last_token_info: dict[str, Any] = {}
    display_name = ""
    name_source = "fallback"
    try:
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if event.get("type") == "session_meta" and not meta:
                    meta = event.get("payload", {})
                    for key in ("title", "name", "summary"):
                        value = meta.get(key)
                        if isinstance(value, str) and value.strip():
                            display_name = clean_prompt_name(value)
                            name_source = f"session_meta.{key}"
                elif event.get("type") == "event_msg" and event.get("payload", {}).get("type") == "token_count":
                    last_token_info = event.get("payload", {}).get("info", {})
                elif not display_name and event.get("type") == "response_item":
                    payload = event.get("payload", {})
                    if payload.get("type") == "message" and payload.get("role") == "user":
                        text = text_from_content(payload.get("content"))
                        if text and not is_bootstrap_prompt(text):
                            display_name = clean_prompt_name(text)
                            name_source = "first_user_prompt"
                elif not display_name and event.get("type") == "turn_context":
                    value = event.get("payload", {}).get("summary")
                    if isinstance(value, str) and value.strip() and value != "auto":
                        display_name = clean_prompt_name(value)
                        name_source = "turn_context.summary"
    except OSError:
        pass

    usage = last_token_info.get("last_token_usage", {})
    cwd = meta.get("cwd") or ""
    if not display_name:
        display_name = Path(cwd).name or path.name
    return {
        "id": rollout_id(path),
        "display_name": display_name,
        "name_source": name_source,
        "file": path.name,
        "path": str(path),
        "cwd": cwd,
        "started_at": meta.get("timestamp") or "",
        "mtime": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
        "input_tokens": int(usage.get("input_tokens") or 0),
        "model_context_window": int(last_token_info.get("model_context_window") or 0),
    }


def token_count(text: str) -> int:
    if not text:
        return 0
    return len(ENCODER.encode(text))


def text_from_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                parts.append(str(item.get("text") or item.get("input_text") or ""))
            else:
                parts.append(str(item))
        return "\n".join(part for part in parts if part)
    return ""


def clean_prompt_name(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > 92:
        return f"{text[:89].rstrip()}..."
    return text


def is_bootstrap_prompt(text: str) -> bool:
    stripped = text.lstrip()
    return stripped.startswith("# AGENTS.md instructions") or stripped.startswith("<environment_context>")


def classify_developer_block(text: str) -> str:
    if text.startswith("<skills_instructions>"):
        return "Skills Manifest"
    if text.startswith("<apps_instructions>"):
        return "Apps Instructions"
    if text.startswith("<plugins_instructions>"):
        return "Plugins Instructions"
    if text.startswith("<permissions instructions>"):
        return "Permissions"
    if text.startswith("<collaboration_mode>"):
        return "Collaboration Mode"
    if text.startswith("## Memory"):
        return "Memory Policy"
    if text.startswith("# Instructions") or "You are Codex" in text[:300]:
        return "Developer Runtime Rules"
    return "Developer Other"


def summarize_session(path: Path) -> dict[str, Any]:
    base_tokens = 0
    developer_components: dict[str, int] = {}
    user_tokens = 0
    assistant_tokens = 0
    tool_tokens = 0
    token_events: list[dict[str, Any]] = []
    skill_entries = 0
    disabled_skills: list[str] = []

    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            event_type = event.get("type")
            payload = event.get("payload", {})

            if event_type == "session_meta":
                base_text = payload.get("base_instructions", {}).get("text", "")
                base_tokens += token_count(base_text)
                continue

            if event_type == "event_msg" and payload.get("type") == "token_count":
                token_events.append(payload.get("info", {}))
                continue

            if event_type != "response_item":
                continue

            item_type = payload.get("type")
            role = payload.get("role")
            content = text_from_content(payload.get("content"))

            if item_type == "message":
                if role == "developer":
                    for block in payload.get("content", []):
                        block_text = block.get("text", "") if isinstance(block, dict) else str(block)
                        label = classify_developer_block(block_text)
                        developer_components[label] = developer_components.get(label, 0) + token_count(block_text)
                        if label == "Skills Manifest":
                            skill_entries = len(
                                [
                                    ln
                                    for ln in block_text.splitlines()
                                    if ln.startswith("- ") and "(file:" in ln
                                ]
                            )
                elif role == "user":
                    user_tokens += token_count(content)
                    disabled_skills.extend(
                        re.findall(r'name\s*=\s*"([^"]+)"\s*\n\s*enabled\s*=\s*false', content)
                    )
                elif role == "assistant":
                    assistant_tokens += token_count(content)
            elif item_type in {"function_call", "function_call_output"}:
                tool_tokens += token_count(json.dumps(payload, ensure_ascii=False))

    last = token_events[-1] if token_events else {}
    usage = last.get("last_token_usage", {})
    window = int(last.get("model_context_window") or 0)
    input_tokens = int(usage.get("input_tokens") or 0)
    output_tokens = int(usage.get("output_tokens") or 0)
    reasoning_tokens = int(usage.get("reasoning_output_tokens") or 0)
    cached_tokens = int(usage.get("cached_input_tokens") or 0)

    components = [
        {"name": "Base Instructions", "tokens": base_tokens, "kind": "system"},
        *[
            {"name": name, "tokens": tokens, "kind": "developer"}
            for name, tokens in sorted(developer_components.items(), key=lambda item: item[1], reverse=True)
        ],
        {"name": "User Messages", "tokens": user_tokens, "kind": "conversation"},
        {"name": "Assistant Messages", "tokens": assistant_tokens, "kind": "conversation"},
        {"name": "Tool Calls + Outputs", "tokens": tool_tokens, "kind": "tools"},
        {"name": "Current Output", "tokens": output_tokens, "kind": "output"},
        {"name": "Reasoning Output", "tokens": reasoning_tokens, "kind": "output"},
    ]

    for component in components:
        component["pct_window"] = (component["tokens"] / window * 100) if window else 0
        component["pct_input"] = (component["tokens"] / input_tokens * 100) if input_tokens else 0

    skills_tokens = developer_components.get("Skills Manifest", 0)
    skill_budget_tokens = round(window * 0.02) if window else 0

    return {
        "session_id": rollout_id(path),
        "rollout": str(path),
        "rollout_mtime": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
        "model_context_window": window,
        "last_input_tokens": input_tokens,
        "last_output_tokens": output_tokens,
        "last_reasoning_tokens": reasoning_tokens,
        "cached_input_tokens": cached_tokens,
        "used_pct_window": (input_tokens / window * 100) if window else 0,
        "remaining_tokens": max(window - input_tokens, 0) if window else 0,
        "components": components,
        "skills": {
            "tokens": skills_tokens,
            "entries": skill_entries,
            "budget_tokens": skill_budget_tokens,
            "pct_budget": (skills_tokens / skill_budget_tokens * 100) if skill_budget_tokens else 0,
            "pct_window": (skills_tokens / window * 100) if window else 0,
            "disabled": sorted(set(disabled_skills)),
        },
    }


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/context")
def context(session: str | None = Query(default=None)) -> dict[str, Any]:
    path = path_for_session(session)
    if path is None:
        return {"error": f"No matching Codex rollout found under {SESSION_ROOT}"}
    return summarize_session(path)


@app.get("/api/sessions")
def sessions(limit: int = Query(default=30, ge=1, le=200)) -> dict[str, Any]:
    items = [session_meta(path) for path in rollout_files()[:limit]]
    return {"sessions": items, "latest": items[0]["id"] if items else None}
