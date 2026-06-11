#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


CODEX_HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
OUT_DIR = CODEX_HOME / "thread-organization"
DB_PATH = CODEX_HOME / "state_5.sqlite"
WORKSPACE_ROOT = Path(os.environ.get("CODEX_WORKSPACE_ROOT", Path.home() / "Documents" / "Codex")).expanduser()
THREADS_ROOT = Path(os.environ.get("CODEX_THREADS_ROOT", WORKSPACE_ROOT / "threads")).expanduser()
PROJECT_WORK_ROOT = Path(os.environ.get("CODEX_PROJECT_WORK_ROOT", Path.home() / "work")).expanduser()
PROJECT_WORK_PREFIX = str(PROJECT_WORK_ROOT) + "/"
GENERATED_VIEWS_DIR = OUT_DIR / "generated"
BACKUP_DIR = OUT_DIR / "backups"
AUTOMATION_MEMORY_DIR = CODEX_HOME / "automations" / "hourly-thread-organization"
RUN_STATE_PATH = OUT_DIR / "last-run.json"
TITLE_PREFIX_RUN_PATH = OUT_DIR / "last-title-prefix-run.json"
CWD_NORMALIZATION_RUN_PATH = OUT_DIR / "last-cwd-normalization-run.json"
AUTO_ARCHIVE_RUN_PATH = OUT_DIR / "last-auto-archive-run.json"


NOISY_TITLE_PREFIX_REPLACEMENTS = {
    "removed-archive-placeholder": "archive",
    "removed-empty-thread": "archive",
}


WORKSPACE_ROUTE_OVERRIDES: dict[str, str] = {}


LANES = {
    "ship": {
        "label": "SHIP",
        "profile": "Issue Implementation Worker",
        "description": "Implementation work with one behavior, one issue, one PR when possible.",
    },
    "review": {
        "label": "REVIEW",
        "profile": "PR Review Auditor",
        "description": "Find bugs, regressions, drift, weak tests, and issue/PR misalignment.",
    },
    "gate": {
        "label": "GATE",
        "profile": "CI / PR Gatekeeper",
        "description": "CI, PR status, review threads, retests, merge readiness.",
    },
    "ops": {
        "label": "OPS",
        "profile": "Ops & Runtime Safety Scout",
        "description": "SSH, services, homelab, local runtime, browser/computer-use, safety checks.",
    },
    "research": {
        "label": "RESEARCH",
        "profile": "Product / Workflow Research Analyst",
        "description": "Market/product/workflow research with evidence, alternatives, MVP, kill criteria.",
    },
    "system": {
        "label": "SYSTEM",
        "profile": "No subagent by default",
        "description": "Prompting, skills, Codex configuration, automations, handoffs, organization.",
    },
    "lab": {
        "label": "LAB",
        "profile": "Use a domain skill first",
        "description": "CAD, 3D, image, UI exploration, prototypes, one-off creative work.",
    },
    "archive": {
        "label": "ARCHIVE",
        "profile": "No subagent by default",
        "description": "Done, stale, duplicate, or too small for workflow orchestration.",
    },
}


RULES = [
    ("research", re.compile(r"\b(recherche|research|trouver|idees?|opportunit|demande|market|benchmark|moteurs?|workflow agentic|visual workflow|product|mvp|onboarding|oauth|marketplace)\b", re.I)),
    ("ship", re.compile(r"\b(implement|implemente|impl[ée]mente|met en place l['’ ]issue|fix|corrige|feature|issue #|starter|monorepo|migration|refactor|tdd)\b", re.I)),
    ("review", re.compile(r"\b(review|revue|auditer|audit|revoir|retours? de review|code review|review des issues?|review du projet|commits?)\b", re.I)),
    ("gate", re.compile(r"\b(ci|checks?|pull request|merge|push|commit|retest|review thread|dependency|dependance|codeql|node 20|warning|gates?)\b", re.I)),
    ("ops", re.compile(r"\b(ssh|vps|homelab|serveur|service|systemd|docker|coolify|computer[- ]use|browser|chrome|safari|mail|linkedin|telegram|veille|mcp|runtime|apps?|ouvrir|list_apps)\b", re.I)),
    ("lab", re.compile(r"\b(3d|cad|cylindre|prusa|slicer|step|stl|emoji|slack|design|landing|ui|dashboard|deck|game|rpg|image)\b", re.I)),
    ("system", re.compile(r"\b(goal|prompt|skill|codex usage|agents\.md|handoff|organization|organisation|threads?|automation|weekly|guide|installer|subagent|workflow)\b", re.I)),
]


@dataclass
class ThreadRow:
    id: str
    title: str
    updated_at: int
    created_at: int
    archived: int
    cwd: str
    first_user_message: str
    preview: str
    tokens_used: int


def title_context(title: str) -> str | None:
    match = re.match(r"^\[([^\]]+)\]\s+", title.strip())
    if not match:
        return None
    return sanitize_context_label(match.group(1))


def workspace_label(cwd: str, title: str = "") -> str:
    threads_prefix = str(THREADS_ROOT) + "/"
    if cwd.startswith(threads_prefix):
        return Path(cwd).name or title_context(title) or "codex"
    if cwd == str(WORKSPACE_ROOT):
        return title_context(title) or "codex"

    path = Path(cwd)
    parts = path.parts
    if len(parts) >= 5 and Path(*parts[:5]) == WORKSPACE_ROOT:
        relative_parts = parts[5:]
        if relative_parts:
            top_level = relative_parts[0]
            if top_level in WORKSPACE_ROUTE_OVERRIDES:
                return WORKSPACE_ROUTE_OVERRIDES[top_level]
    if "work" in parts:
        idx = parts.index("work")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    if "_90-archive-empty" in parts:
        return "removed-archive-placeholder"
    if "_30-automation-tools" in parts:
        return "_30-automation-tools"
    if "_00-router" in parts:
        return "_00-router"
    return path.name or "unknown"


def sanitize_text(text: str) -> str:
    project_prefix = re.escape(str(PROJECT_WORK_ROOT))
    home_prefix = re.escape(str(Path.home()))
    text = re.sub(rf"{project_prefix}/([A-Za-z0-9._-]+)", r"\1", text)
    text = re.sub(rf"{home_prefix}/[^\s|,)]+", "[home-path]", text)
    text = re.sub(r"~/[^\s|,)]+", "[home-path]", text)
    return text


def short_title(title: str, limit: int = 120) -> str:
    compact = re.sub(r"\s+", " ", sanitize_text(title)).strip()
    if len(compact) <= limit:
        return compact
    return compact[: limit - 1].rstrip() + "..."


def timestamp_iso(timestamp: int) -> str:
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def generated_iso(generated_at: datetime) -> str:
    return generated_at.isoformat(timespec="seconds").replace("+00:00", "Z")


def is_command_only(text: str) -> bool:
    compact = re.sub(r"\s+", " ", text).strip()
    if len(compact) > 120:
        return False
    return bool(
        re.match(
            r"^(git|find|cat|ls|pnpm|npm|yarn|rg|sed|jq|sqlite3|pwd|wc|head|tail)\b",
            compact,
            re.I,
        )
    )


def classify(text: str, archived: int) -> str:
    if text.lstrip().startswith("Automation:"):
        return "system"
    if is_command_only(text):
        return "system"
    if archived:
        # Keep archived threads in their semantic lane when strongly useful as reference.
        if re.search(r"\b(recherche|research|prompt|skill|guide|workflow|handoff|automation)\b", text, re.I):
            pass
        else:
            return "archive"

    matches: list[tuple[int, str]] = []
    for index, (lane, pattern) in enumerate(RULES):
        if pattern.search(text):
            matches.append((index, lane))
    if not matches:
        return "archive" if archived else "system"

    # Priority is encoded by RULES order: gates/reviews/ops beat broad system terms.
    return sorted(matches)[0][1]


def status_for(row: ThreadRow, lane: str, latest_timestamp: int) -> str:
    age_days = max(0, int((latest_timestamp - row.updated_at) / 86400))
    text = f"{row.title}\n{row.first_user_message}\n{row.preview}"

    if row.archived:
        if lane in {"research", "system"}:
            return "reference"
        return "archive"
    if text.lstrip().startswith("Automation:") or is_command_only(row.title):
        return "reference"
    if re.search(r"\b(retest|ci|merge|review thread|checks?|waiting|bloqu|blocked)\b", text, re.I):
        return "waiting"
    if age_days <= 7 and lane in {"ship", "review", "gate", "ops", "research", "system"}:
        return "now"
    if lane in {"research", "system"}:
        return "reference"
    if age_days <= 21:
        return "next"
    return "archive_candidate"


def load_threads() -> list[ThreadRow]:
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            select id, title, updated_at, created_at, archived, cwd,
                   first_user_message, preview, tokens_used
            from threads
            order by updated_at desc
            """
        ).fetchall()
    return [
        ThreadRow(
            id=row["id"],
            title=row["title"] or "",
            updated_at=int(row["updated_at"] or 0),
            created_at=int(row["created_at"] or 0),
            archived=int(row["archived"] or 0),
            cwd=row["cwd"] or "",
            first_user_message=row["first_user_message"] or "",
            preview=row["preview"] or "",
            tokens_used=int(row["tokens_used"] or 0),
        )
        for row in rows
    ]


def project_from_work_cwd(cwd: str) -> str | None:
    if not cwd.startswith(PROJECT_WORK_PREFIX):
        return None
    rest = cwd[len(PROJECT_WORK_PREFIX) :].strip("/")
    if not rest:
        return None
    return rest.split("/", 1)[0]


def sanitize_context_label(label: str) -> str:
    compact = re.sub(r"[^A-Za-z0-9._-]+", "-", label.strip().lower())
    compact = compact.strip("-")
    return compact or "codex"


def context_label_for_cwd(cwd: str) -> str:
    project = project_from_work_cwd(cwd)
    if project:
        return sanitize_context_label(project)

    root_prefix = str(WORKSPACE_ROOT) + "/"
    if cwd.startswith(root_prefix):
        label = workspace_label(cwd)
        if label == "removed-empty-thread":
            return "archive"
        if label in {"_00-router", "_30-automation-tools"}:
            return sanitize_context_label(label.lstrip("_0123456789-") or label)
        return sanitize_context_label(label)

    if cwd == str(WORKSPACE_ROOT):
        return "codex"

    name = Path(cwd).name
    if name:
        return sanitize_context_label(name)
    return "codex"


def backup_sqlite(generated_at: datetime, reason: str) -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup_path = BACKUP_DIR / f"state_5.sqlite.backup-{generated_at.strftime('%Y%m%dT%H%M%SZ')}-{reason}.sqlite"
    with sqlite3.connect(DB_PATH) as src, sqlite3.connect(backup_path) as dst:
        src.backup(dst)
    return backup_path


def strip_empty_title_prefix(title: str) -> str:
    return re.sub(r"^\[\]\s*", "", title).strip()


def ensure_context_title_prefixes(generated_at: datetime) -> dict:
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(
            "select id, cwd, title from threads order by updated_at desc",
        ).fetchall()

    updates: list[tuple[str, str, str, str]] = []
    for thread_id, cwd, title in rows:
        context = context_label_for_cwd(cwd or "")
        current = (title or "Untitled").strip() or "Untitled"
        current = strip_empty_title_prefix(current) or "Untitled"
        expected_prefix = f"[{context}] "

        prefix_match = re.match(r"^\[([^\]]+)\]\s*(.*)$", current, re.S)
        if prefix_match:
            current_prefix = prefix_match.group(1).strip()
            rest = strip_empty_title_prefix(prefix_match.group(2).strip()) or "Untitled"
            replacement = NOISY_TITLE_PREFIX_REPLACEMENTS.get(current_prefix)
            if replacement:
                new_title = f"[{replacement}] {rest}"
                if new_title != current:
                    updates.append((str(thread_id), new_title, replacement, current))
                continue
            if current.startswith(expected_prefix):
                new_title = f"{expected_prefix}{rest}"
                if new_title != current:
                    updates.append((str(thread_id), new_title, context, current))
                continue
            continue

        # Preserve explicit non-empty user/project prefixes. This routine fills
        # missing context and fixes empty `[]` prefixes only.
        updates.append((str(thread_id), expected_prefix + current, context, current))

    result = {
        "generated_at": generated_iso(generated_at),
        "threads_seen": len(rows),
        "changed": len(updates),
        "backup_path": None,
        "contexts": {},
        "sample_ids": [thread_id for thread_id, _, _, _ in updates[:12]],
    }

    if not updates:
        TITLE_PREFIX_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        return result

    backup_path = backup_sqlite(generated_at, "before-context-title-prefix")

    with sqlite3.connect(DB_PATH) as conn:
        for thread_id, new_title, context, _ in updates:
            conn.execute("update threads set title = ? where id = ?", (new_title, thread_id))
            result["contexts"][context] = result["contexts"].get(context, 0) + 1
        conn.commit()

    result["backup_path"] = str(backup_path)
    TITLE_PREFIX_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


def thread_context_dir(title: str, archived: int) -> Path:
    context = title_context(title) or "codex"
    if archived or context == "archive":
        context = "archive"
    return THREADS_ROOT / sanitize_context_label(context)


def normalize_thread_cwds(generated_at: datetime) -> dict:
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(
            "select id, cwd, title, archived from threads order by updated_at desc",
        ).fetchall()

    desired_dirs = sorted({thread_context_dir(title or "", int(archived or 0)) for _, _, title, archived in rows})
    for directory in desired_dirs:
        directory.mkdir(parents=True, exist_ok=True)

    updates = []
    for thread_id, cwd, title, archived in rows:
        desired_cwd = str(thread_context_dir(title or "", int(archived or 0)))
        if cwd != desired_cwd:
            updates.append((str(thread_id), cwd, desired_cwd))

    result = {
        "generated_at": generated_iso(generated_at),
        "threads_seen": len(rows),
        "changed": len(updates),
        "threads_root": str(THREADS_ROOT),
        "context_directories": [str(directory) for directory in desired_dirs],
        "backup_path": None,
        "sample_changes": [{"old": cwd, "new": desired_cwd} for _, cwd, desired_cwd in updates[:20]],
    }

    if not updates:
        CWD_NORMALIZATION_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        return result

    backup_path = backup_sqlite(generated_at, "before-thread-cwd-normalization")
    with sqlite3.connect(DB_PATH) as conn:
        conn.executemany("update threads set cwd = ? where id = ?", [(desired_cwd, thread_id) for thread_id, _, desired_cwd in updates])
        conn.commit()

    result["backup_path"] = str(backup_path)
    CWD_NORMALIZATION_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


def auto_archive_candidates(items: list[dict], generated_at: datetime) -> dict:
    candidates = [
        item
        for item in items
        if item["status"] == "archive_candidate" and not item["archived_in_codex"]
    ]
    result = {
        "generated_at": generated_iso(generated_at),
        "changed": len(candidates),
        "backup_path": None,
        "sample_ids": [item["id"] for item in candidates[:20]],
    }

    if not candidates:
        AUTO_ARCHIVE_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        return result

    backup_path = backup_sqlite(generated_at, "before-auto-archive-candidates")
    archived_at = int(generated_at.timestamp())
    with sqlite3.connect(DB_PATH) as conn:
        conn.executemany(
            "update threads set archived = 1, archived_at = ? where id = ?",
            [(archived_at, item["id"]) for item in candidates],
        )
        conn.commit()

    result["backup_path"] = str(backup_path)
    AUTO_ARCHIVE_RUN_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


def enrich(rows: list[ThreadRow]) -> list[dict]:
    latest = max((row.updated_at for row in rows), default=0)
    items = []
    for row in rows:
        workspace = workspace_label(row.cwd, row.title)
        text = f"{row.title}\n{row.first_user_message}\n{row.preview}\n{workspace}"
        lane = classify(text, row.archived)
        status = status_for(row, lane, latest)
        updated = datetime.fromtimestamp(row.updated_at, tz=timezone.utc).strftime("%Y-%m-%d")
        items.append(
            {
                "id": row.id,
                "updated_at": row.updated_at,
                "created_at": row.created_at,
                "updated_at_iso": timestamp_iso(row.updated_at),
                "created_at_iso": timestamp_iso(row.created_at),
                "updated": updated,
                "title": short_title(row.title),
                "workspace": workspace,
                "lane": LANES[lane]["label"],
                "profile": LANES[lane]["profile"],
                "status": status,
                "archived_in_codex": bool(row.archived),
                "tokens_used": row.tokens_used,
            }
        )
    return items


def write_json(items: list[dict]) -> None:
    (OUT_DIR / "thread-index.json").write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n")


def write_csv(items: list[dict]) -> None:
    if not items:
        (OUT_DIR / "thread-index.csv").write_text("")
        return
    with (OUT_DIR / "thread-index.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(items[0].keys()))
        writer.writeheader()
        writer.writerows(items)


def md_table(items: list[dict], columns: list[str]) -> str:
    lines = []
    lines.append("| " + " | ".join(columns) + " |")
    lines.append("| " + " | ".join("---" for _ in columns) + " |")
    for item in items:
        values = [str(item[column]).replace("|", "\\|") for column in columns]
        lines.append("| " + " | ".join(values) + " |")
    return "\n".join(lines)


def write_index_md(items: list[dict]) -> None:
    counts_by_lane: dict[str, int] = {}
    counts_by_status: dict[str, int] = {}
    for item in items:
        counts_by_lane[item["lane"]] = counts_by_lane.get(item["lane"], 0) + 1
        counts_by_status[item["status"]] = counts_by_status.get(item["status"], 0) + 1

    lines = [
        "# Codex Thread Index",
        "",
        "Generated from the local Codex `threads` database after bounded organization maintenance.",
        "",
        "## Counts",
        "",
        f"- Total threads: {len(items)}",
        "- By lane: " + ", ".join(f"{key}={value}" for key, value in sorted(counts_by_lane.items())),
        "- By status: " + ", ".join(f"{key}={value}" for key, value in sorted(counts_by_status.items())),
        "",
        "## Threads",
        "",
        md_table(items, ["updated", "status", "lane", "profile", "workspace", "title", "id"]),
        "",
    ]
    (OUT_DIR / "thread-index.md").write_text("\n".join(lines))


def write_queues(items: list[dict]) -> None:
    def select(status: str, limit: int | None = None) -> list[dict]:
        selected = [item for item in items if item["status"] == status]
        return selected if limit is None else selected[:limit]

    sections = [
        ("Now", select("now", 25), "Threads worth continuing or consolidating soon."),
        ("Waiting", select("waiting", 25), "Threads that need CI, PR, review-thread, retest, or external-state follow-up."),
        ("Next", select("next", 25), "Recent but less urgent threads that can become explicit workflows if resumed."),
        ("Reference", select("reference", 40), "Research, prompting, automation, and reusable context."),
        ("Archive Candidates", select("archive_candidate", 40) + select("archive", 40), "Stale, duplicate, done, or one-off threads."),
    ]

    lines = [
        "# Codex Thread Queues",
        "",
        "This file is the operational view. Use it before opening a new long-running thread.",
        "",
    ]
    for title, rows, description in sections:
        lines.extend([f"## {title}", "", description, ""])
        if rows:
            lines.append(md_table(rows, ["updated", "lane", "profile", "workspace", "title", "id"]))
        else:
            lines.append("_None._")
        lines.append("")

    (OUT_DIR / "queues.md").write_text("\n".join(lines))


def suggested_title(item: dict) -> str:
    prefix = item["lane"]
    workspace = item["workspace"]
    title = item["title"]
    if item["status"] == "waiting":
        prefix = "WAIT"
    elif item["status"] == "reference":
        prefix = "REF"
    elif item["status"] in {"archive", "archive_candidate"}:
        prefix = "ARCHIVE"
    return short_title(f"{prefix} - {workspace} - {title}", 100)


def write_rename_plan(items: list[dict]) -> None:
    active = [item for item in items if item["status"] in {"now", "waiting", "next", "reference"}][:80]
    rows = [
        {
            "status": item["status"],
            "current": item["title"],
            "suggested": suggested_title(item),
            "id": item["id"],
        }
        for item in active
    ]
    lines = [
        "# Suggested Thread Titles",
        "",
        "Do not apply this file mechanically. It is a safe rename plan for human review if Codex later exposes a supported thread-title editing path.",
        "",
        md_table(rows, ["status", "current", "suggested", "id"]),
        "",
    ]
    (OUT_DIR / "suggested-thread-titles.md").write_text("\n".join(lines))


def count_by(items: list[dict], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in items:
        value = str(item.get(key, "unknown"))
        counts[value] = counts.get(value, 0) + 1
    return dict(sorted(counts.items()))


def is_automation_item(item: dict) -> bool:
    return str(item.get("title", "")).startswith("Automation:")


def load_previous_state() -> dict | None:
    if not RUN_STATE_PATH.exists():
        return None
    try:
        return json.loads(RUN_STATE_PATH.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def changed_since_previous(items: list[dict], previous: dict | None) -> tuple[list[dict], list[dict]]:
    if not previous:
        return [], []

    previous_threads = previous.get("threads", {})
    new_items: list[dict] = []
    updated_items: list[dict] = []
    for item in items:
        thread_id = item["id"]
        previous_updated_at = previous_threads.get(thread_id)
        if previous_updated_at is None:
            new_items.append(item)
        elif int(item["updated_at"]) > int(previous_updated_at):
            updated_items.append(item)
    return new_items, updated_items


def write_run_state(items: list[dict], generated_at: datetime) -> None:
    state = {
        "generated_at": generated_iso(generated_at),
        "thread_count": len(items),
        "counts_by_lane": count_by(items, "lane"),
        "counts_by_status": count_by(items, "status"),
        "threads": {item["id"]: item["updated_at"] for item in items},
    }
    RUN_STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")


def workspace_inventory() -> dict:
    inventory = {
        "root": str(WORKSPACE_ROOT),
        "exists": WORKSPACE_ROOT.exists(),
        "total_directories": 0,
        "lane_directories": [],
        "dated_or_legacy_directories": [],
        "empty_directories": [],
        "other_directories": [],
    }
    if not WORKSPACE_ROOT.exists():
        return inventory

    lane_pattern = re.compile(r"^_\d{2}-")
    dated_pattern = re.compile(r"^\d{4}-\d{2}-\d{2}")
    entries = sorted(path for path in WORKSPACE_ROOT.iterdir() if path.is_dir())
    inventory["total_directories"] = len(entries)

    for path in entries:
        info = {
            "name": path.name,
            "is_symlink": path.is_symlink(),
            "modified_at": timestamp_iso(int(path.stat().st_mtime)),
        }
        if lane_pattern.match(path.name):
            inventory["lane_directories"].append(info)
        elif dated_pattern.match(path.name):
            inventory["dated_or_legacy_directories"].append(info)
        else:
            inventory["other_directories"].append(info)

        if not path.is_symlink():
            try:
                if not any(path.iterdir()):
                    inventory["empty_directories"].append(info)
            except OSError:
                pass

    return inventory


def bullet_items(items: list[dict], columns: list[str], limit: int = 12) -> list[str]:
    if not items:
        return ["- _Aucun._"]
    lines = []
    for item in items[:limit]:
        parts = [str(item[column]) for column in columns]
        lines.append("- " + " | ".join(parts))
    if len(items) > limit:
        lines.append(f"- ... {len(items) - limit} autres")
    return lines


def write_hourly_dashboard(
    items: list[dict],
    inventory: dict,
    previous: dict | None,
    generated_at: datetime,
    title_prefix_result: dict,
    cwd_normalization_result: dict,
    auto_archive_result: dict,
) -> None:
    new_items, updated_items = changed_since_previous(items, previous)
    now = int(generated_at.timestamp())
    recent_cutoff = now - 24 * 60 * 60
    recent_active = [
        item
        for item in items
        if item["updated_at"] >= recent_cutoff
        and item["status"] in {"now", "waiting", "next"}
        and not is_automation_item(item)
    ]
    waiting = [item for item in items if item["status"] == "waiting"]
    high_token = [
        item
        for item in sorted(items, key=lambda row: int(row["tokens_used"]), reverse=True)
        if int(item["tokens_used"]) >= 20_000_000 and item["status"] not in {"archive", "archive_candidate"}
    ]
    archive_candidates = [item for item in items if item["status"] in {"archive_candidate", "archive"}]

    counts_by_lane = count_by(items, "lane")
    counts_by_status = count_by(items, "status")
    generated = generated_iso(generated_at)
    first_run_note = "baseline creee" if previous is None else f"{len(new_items)} nouveaux, {len(updated_items)} mis a jour"

    lines = [
        "# Hourly Thread Organization Dashboard",
        "",
        f"Generated UTC: {generated}",
        "",
        "## Safety",
        "",
        "- Mode: sidecar reports plus limited thread organization maintenance.",
        "- Codex SQLite mutation is limited to contextual `threads.title` prefixes, all-thread `threads.cwd` normalization, and stale archive-candidate archival.",
        "- A SQLite backup is created before each mutation class.",
        "- No automatic deletion, move, push, or external action.",
        "- No broad thread renaming beyond missing context prefixes such as `[portfolio]` or `[codex]`.",
        "",
        "## Snapshot",
        "",
        f"- Codex threads: {len(items)}.",
        "- By lane: " + ", ".join(f"{key}={value}" for key, value in counts_by_lane.items()),
        "- By status: " + ", ".join(f"{key}={value}" for key, value in counts_by_status.items()),
        f"- Since previous hourly run: {first_run_note}.",
        f"- Workspace directories: {inventory['total_directories']} direct, {len(inventory['lane_directories'])} lanes, {len(inventory['dated_or_legacy_directories'])} dated top-level, {len(inventory['empty_directories'])} empty.",
        f"- Context title prefixes applied this run: {title_prefix_result['changed']}.",
        f"- Thread cwd values normalized this run: {cwd_normalization_result['changed']}.",
        f"- Archive candidates archived this run: {auto_archive_result['changed']}.",
        "",
        "## Observed Workflow",
        "",
        "- The stable organization model is lane-based: SHIP, REVIEW, GATE, OPS, RESEARCH, SYSTEM, LAB, ARCHIVE.",
        "- Recurring automation threads are useful as references, but should not become active project-control threads.",
        f"- Codex's internal database uses managed context folders under `{THREADS_ROOT}`; visible context also lives in the `[context]` title prefix.",
        "- Long-running or high-token threads need explicit closeout/handoff before continuation.",
        "",
        "## Focus: Last 24h",
        "",
        *bullet_items(recent_active, ["updated_at_iso", "status", "lane", "workspace", "title", "id"], 18),
        "",
        "## Waiting / Blocked",
        "",
        *bullet_items(waiting, ["updated_at_iso", "lane", "workspace", "title", "id"], 12),
        "",
        "## High-Token Threads To Close Or Handoff",
        "",
        *bullet_items(high_token, ["updated_at_iso", "tokens_used", "lane", "workspace", "title", "id"], 12),
        "",
        "## New Since Previous Run",
        "",
        *bullet_items(new_items, ["updated_at_iso", "status", "lane", "workspace", "title", "id"], 12),
        "",
        "## Updated Since Previous Run",
        "",
        *bullet_items(updated_items, ["updated_at_iso", "status", "lane", "workspace", "title", "id"], 12),
        "",
        "## Cleanup Candidates",
        "",
        "These are candidates only. Review before taking action.",
        "",
        *bullet_items(archive_candidates, ["updated_at_iso", "status", "lane", "workspace", "title", "id"], 20),
        "",
        "## Where To Start",
        "",
        "1. Open `~/.codex/thread-organization/queues.md` for the operational queues.",
        "2. Open `~/.codex/thread-organization/generated/hourly-thread-dashboard.md` for the generated dashboard copy.",
        "3. Close or handoff high-token threads before resuming them.",
        f"4. Create durable project work in the actual project repository; use `{THREADS_ROOT}/<context>` only as the Codex UI grouping folder.",
        "",
    ]
    content = "\n".join(lines)
    (OUT_DIR / "hourly-dashboard.md").write_text(content)

    GENERATED_VIEWS_DIR.mkdir(parents=True, exist_ok=True)
    (GENERATED_VIEWS_DIR / "hourly-thread-dashboard.md").write_text(content)


def write_cleanup_report(items: list[dict], inventory: dict, generated_at: datetime) -> None:
    archive_candidates = [item for item in items if item["status"] in {"archive_candidate", "archive"}]
    empty_directories = inventory["empty_directories"]
    dated_or_legacy = inventory["dated_or_legacy_directories"]

    lines = [
        "# Thread Cleanup Candidates",
        "",
        f"Generated UTC: {generated_iso(generated_at)}",
        "",
        "This file is an inventory. The hourly routine may already have archived stale `archive_candidate` threads; nothing here was deleted, moved, pushed, or externally changed.",
        "",
        "## Empty Workspace Directories",
        "",
    ]
    if empty_directories:
        lines.extend(f"- {item['name']} | modified {item['modified_at']}" for item in empty_directories)
    else:
        lines.append("- _Aucun._")

    lines.extend(
        [
            "",
            "## Dated Non-Empty Top-Level Directories",
            "",
            "These are not empty and were not deleted automatically. They should not receive new durable work unless the user explicitly resumes that exact thread.",
            "",
        ]
    )
    if dated_or_legacy:
        lines.extend(f"- {item['name']} | modified {item['modified_at']}" for item in dated_or_legacy[:80])
        if len(dated_or_legacy) > 80:
            lines.append(f"- ... {len(dated_or_legacy) - 80} autres")
    else:
        lines.append("- _Aucun._")

    lines.extend(
        [
            "",
            "## Codex Archive Candidates",
            "",
            *bullet_items(archive_candidates, ["updated_at_iso", "status", "lane", "workspace", "title", "id"], 80),
            "",
        ]
    )
    content = "\n".join(lines)
    (OUT_DIR / "cleanup-candidates.md").write_text(content)

    GENERATED_VIEWS_DIR.mkdir(parents=True, exist_ok=True)
    (GENERATED_VIEWS_DIR / "thread-cleanup-candidates.md").write_text(content)


def write_generated_views_readme(generated_at: datetime) -> None:
    GENERATED_VIEWS_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Generated Thread Views",
        "",
        f"Last generated UTC: {generated_iso(generated_at)}",
        "",
        "Generated by `~/.codex/thread-organization/build_thread_organization.py`.",
        "",
        "- `hourly-thread-dashboard.md`: operational dashboard for recent, waiting, high-token, and changed threads.",
        "- `thread-cleanup-candidates.md`: safe inventory of archive candidates and legacy/empty workspaces.",
        "",
        "These files are regenerated. Keep durable manual decisions in project repositories or dedicated notes.",
        "",
    ]
    (GENERATED_VIEWS_DIR / "README.md").write_text("\n".join(lines))


def write_run_summary_json(
    items: list[dict],
    inventory: dict,
    previous: dict | None,
    generated_at: datetime,
    title_prefix_result: dict,
    cwd_normalization_result: dict,
    auto_archive_result: dict,
) -> None:
    new_items, updated_items = changed_since_previous(items, previous)
    summary = {
        "generated_at": generated_iso(generated_at),
        "thread_count": len(items),
        "counts_by_lane": count_by(items, "lane"),
        "counts_by_status": count_by(items, "status"),
        "new_thread_ids": [item["id"] for item in new_items],
        "updated_thread_ids": [item["id"] for item in updated_items],
        "workspace_inventory": {
            "root": inventory["root"],
            "exists": inventory["exists"],
            "total_directories": inventory["total_directories"],
            "lane_directories": len(inventory["lane_directories"]),
            "dated_top_level_directories": len(inventory["dated_or_legacy_directories"]),
            "empty_directories": len(inventory["empty_directories"]),
            "other_directories": len(inventory["other_directories"]),
        },
        "title_prefixing": title_prefix_result,
        "cwd_normalization": cwd_normalization_result,
        "auto_archive": auto_archive_result,
    }
    (OUT_DIR / "last-run-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")


def write_automation_memory(
    items: list[dict],
    inventory: dict,
    previous: dict | None,
    generated_at: datetime,
    title_prefix_result: dict,
    cwd_normalization_result: dict,
    auto_archive_result: dict,
) -> None:
    new_items, updated_items = changed_since_previous(items, previous)
    counts_by_status = count_by(items, "status")
    counts_by_lane = count_by(items, "lane")
    high_token_count = len(
        [
            item
            for item in items
            if int(item["tokens_used"]) >= 20_000_000 and item["status"] not in {"archive", "archive_candidate"}
        ]
    )

    AUTOMATION_MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Hourly Thread Organization Memory",
        "",
        f"Last run UTC: {generated_iso(generated_at)}",
        "",
        "## Scope",
        "",
        "- Local deterministic sidecar for Codex thread organization.",
        f"- Reads `{DB_PATH}` and `{WORKSPACE_ROOT}`.",
        "- Writes generated reports under `~/.codex/thread-organization` only.",
        f"- Creates only managed grouping folders under `{THREADS_ROOT}/<context>`.",
        "- Does not create dated, router, lane, symlink, placeholder, or one-off thread folders.",
        "- Mutates `threads.title` only to add missing context prefixes.",
        f"- Mutates `threads.cwd` only to point at managed folders under `{THREADS_ROOT}/<context>`; durable project work remains in the real repo.",
        "- Mutates `threads.archived` only for stale threads classified as `archive_candidate`.",
        "- Creates a SQLite backup before each mutation class.",
        "",
        "## Last Run Summary",
        "",
        f"- Threads indexed: {len(items)}.",
        "- Status counts: " + ", ".join(f"{key}={value}" for key, value in counts_by_status.items()),
        "- Lane counts: " + ", ".join(f"{key}={value}" for key, value in counts_by_lane.items()),
        f"- Since previous run: {len(new_items)} new, {len(updated_items)} updated.",
        f"- Workspace dirs: {inventory['total_directories']} direct, {len(inventory['lane_directories'])} lanes, {len(inventory['dated_or_legacy_directories'])} dated top-level, {len(inventory['empty_directories'])} empty.",
        f"- High-token active/reference threads: {high_token_count}.",
        f"- Context title prefixes applied: {title_prefix_result['changed']}.",
        f"- Title-prefix backup: {title_prefix_result['backup_path'] or 'none needed'}.",
        f"- Thread cwd values normalized: {cwd_normalization_result['changed']}.",
        f"- Cwd-normalization backup: {cwd_normalization_result['backup_path'] or 'none needed'}.",
        f"- Archive candidates archived: {auto_archive_result['changed']}.",
        f"- Auto-archive backup: {auto_archive_result['backup_path'] or 'none needed'}.",
        "",
        "## Decisions",
        "",
        f"- Keep `{WORKSPACE_ROOT}` limited to a managed `threads/` tree; do not recreate router, lane, dated, or placeholder folders.",
        f"- Prefix project threads as `[project] threadTitle` when `cwd` is under `{PROJECT_WORK_ROOT}/<project>`.",
        f"- Prefix threads with the best available context label, then point each thread cwd at `{THREADS_ROOT}/<context>` so the Codex project list stays useful.",
        "- Archive stale `archive_candidate` threads automatically so the main list does not stay crowded.",
        "- Do not create hourly Codex model runs; launchd only regenerates local files.",
        "- Use generated cleanup candidates as review input before any manual cleanup beyond the automatic archive-candidate step.",
        "",
        "## Key Outputs",
        "",
        "- `~/.codex/thread-organization/hourly-dashboard.md`",
        "- `~/.codex/thread-organization/cleanup-candidates.md`",
        "- `~/.codex/thread-organization/generated/hourly-thread-dashboard.md`",
        "- `~/.codex/thread-organization/generated/thread-cleanup-candidates.md`",
        "",
        "## Next Review",
        "",
        "- If hourly reports remain useful, keep launchd enabled.",
        "- If stronger cleanup is wanted, run a separate explicit maintenance step with inventory and rollback.",
        "",
    ]
    (AUTOMATION_MEMORY_DIR / "memory.md").write_text("\n".join(lines))


def write_system_docs(items: list[dict]) -> None:
    lanes_doc = [
        "# Codex Collaboration Operating System",
        "",
        "This organization matches the observed working pattern: direct execution when the target is clear, explicit goals for long work, review/CI loops, risk gates for ops, and compact handoffs.",
        "",
        "## Lanes",
        "",
    ]
    for key, lane in LANES.items():
        lanes_doc.extend(
            [
                f"### {lane['label']}",
                "",
                f"- Profile: {lane['profile']}",
                f"- Purpose: {lane['description']}",
                "",
            ]
        )
    lanes_doc.extend(
        [
            "## Thread Shape",
            "",
            "- One control thread per active project for status, handoff, and queue decisions.",
            "- One SHIP thread per issue or behavior.",
            "- One REVIEW thread per PR, issue set, or change-set review.",
            "- One GATE thread per PR when CI/review state becomes the main blocker.",
            "- One OPS thread per host, service, runtime, or incident.",
            "- One RESEARCH thread per product/workflow decision.",
            "- Archive or reference everything else quickly; do not let one-off browser, CAD, or social tasks become project control threads.",
            "",
            "## Naming Convention",
            "",
            "```text",
            "SHIP - <project> - issue #N - <behavior>",
            "REVIEW - <project> - PR #N or issues A-B",
            "GATE - <project> - PR #N - CI/review",
            "OPS - <target> - <incident or check>",
            "RESEARCH - <topic> - <decision>",
            "SYSTEM - codex - <workflow/config>",
            "REF - <topic> - <reusable context>",
            "ARCHIVE - <workspace> - <old title>",
            "```",
            "",
            "## Parent Thread Rule",
            "",
            "The parent thread owns the objective, integration, final validation, commit/push/merge policy, and risky approvals. Subagents own bounded packets only.",
            "",
            "## When Resuming",
            "",
            "Before continuing a thread, ask:",
            "",
            "1. Is this a control, ship, review, gate, ops, research, system, lab, or archive thread?",
            "2. What is the single current objective?",
            "3. Which profile, if any, should be delegated?",
            "4. What evidence proves done?",
            "5. What must not be touched?",
            "",
        ]
    )
    (OUT_DIR / "operating-system.md").write_text("\n".join(lanes_doc))

    routing = [
        "# Workflow Routing",
        "",
        "Use this file to pick the profile before spawning subagents or creating packets.",
        "",
        "## Router",
        "",
        "| User intent | Lane | Profile | Default action |",
        "| --- | --- | --- | --- |",
        "| Implement one issue or behavior | SHIP | Issue Implementation Worker | Spawn worker only for disjoint files; parent integrates |",
        "| Review code, PR, issues, commits | REVIEW | PR Review Auditor | Spawn explorer; read-only by default |",
        "| CI, checks, retest, merge readiness | GATE | CI / PR Gatekeeper | Spawn explorer; promote to worker only for narrow fix |",
        "| SSH, service, runtime, computer-use | OPS | Ops & Runtime Safety Scout | Spawn explorer; read-only first with rollback |",
        "| Product, market, workflow research | RESEARCH | Product / Workflow Research Analyst | Spawn explorer; label claims by evidence strength |",
        "| Prompting, skills, organization | SYSTEM | No subagent by default | Keep local unless there are independent research/docs packets |",
        "| CAD, 3D, image, UI prototype | LAB | Use a domain skill first | Use installed skill; subagent only for independent QA/review |",
        "",
        "## Prompt Prefix",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: <SHIP|REVIEW|GATE|OPS|RESEARCH|SYSTEM|LAB>.",
        "Profile: <profile name or none>.",
        "Objective: <one concrete outcome>.",
        "Out of scope: <what not to touch>.",
        "Validation: <commands, checks, sources, or artifacts>.",
        "Delegation: <allowed subagents and ownership>.",
        "Stop condition: <evidence done or blocked handoff>.",
        "```",
        "",
    ]
    (OUT_DIR / "workflow-routing.md").write_text("\n".join(routing))

    starter_prompts = [
        "# Thread Starter Prompts",
        "",
        "Use these prompts to keep threads aligned with the workflow lanes.",
        "",
        "## Project Control Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: SYSTEM.",
        "Objective: establish the current state of <project> and maintain a compact action queue.",
        "Out of scope: do not implement changes yet.",
        "Validation: inspect current repo state, recent thread index entries, open PR/issues if relevant, and produce NOW/NEXT/WAITING/REFERENCE.",
        "Stop condition: report the queue, risks, and the next recommended SHIP/REVIEW/GATE/OPS/RESEARCH thread.",
        "```",
        "",
        "## Ship Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: SHIP.",
        "Profile: Issue Implementation Worker.",
        "Objective: implement <one behavior or issue>.",
        "Out of scope: unrelated refactors, unrelated features, commit/push/merge unless explicitly requested.",
        "Validation: define expected behavior, add/update focused tests when viable, run targeted validation then broader gates by blast radius.",
        "Delegation: spawn workers only for disjoint files/modules; parent owns integration.",
        "Stop condition: behavior implemented and verified, or blocked with evidence and next input needed.",
        "```",
        "",
        "## Review Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: REVIEW.",
        "Profile: PR Review Auditor.",
        "Objective: review <PR, issue set, commits, or diff> for real bugs, regressions, security risks, drift, and missing tests.",
        "Out of scope: fixing code unless explicitly promoted to SHIP.",
        "Validation: findings are evidence-backed with file/line or exact surface; state no actionable findings if true.",
        "Delegation: spawn explorers by concern if the review is broad.",
        "Stop condition: prioritized findings, questions, and residual validation gaps.",
        "```",
        "",
        "## Gate Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: GATE.",
        "Profile: CI / PR Gatekeeper.",
        "Objective: determine whether <PR/branch> is ready and handle only directly related blockers.",
        "Out of scope: unrelated cleanup, merge/push/force-push unless explicitly authorized.",
        "Validation: inspect authoritative CI/PR/review state, name failed checks/logs, retest narrow then broad.",
        "Delegation: explorer first; worker only for narrow fixes with explicit ownership.",
        "Stop condition: ready, not ready, blocked, or unknown with evidence.",
        "```",
        "",
        "## Ops Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: OPS.",
        "Profile: Ops & Runtime Safety Scout.",
        "Objective: diagnose <host/service/runtime/app issue> safely.",
        "Out of scope: destructive commands, restarts, upgrades, migrations, secrets, prod data, or external mutation without approval.",
        "Validation: facts from commands/logs/config, assumptions marked, rollback and before/after checks for any proposed mutation.",
        "Delegation: read-only explorer first.",
        "Stop condition: diagnosis, safe next steps, risk gates, rollback, verification commands.",
        "```",
        "",
        "## Research Thread",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: RESEARCH.",
        "Profile: Product / Workflow Research Analyst.",
        "Objective: answer <decision question> with evidence.",
        "Out of scope: public posting, outreach, spending, signups, or implementation.",
        "Validation: claims labeled confirmed/approximate/proxy-supported/blocked/unknown; primary or recent sources when relevant.",
        "Delegation: explorer packets by question, not by duplicate broad searches.",
        "Stop condition: decision-oriented synthesis, alternatives, MVP/experiment, kill criteria, open questions.",
        "```",
        "",
        "## Thread Closeout",
        "",
        "```text",
        "Close out this thread.",
        "Produce: final state, files/artifacts changed, validation evidence, remaining risks, follow-up thread lane if any.",
        "Do not start new work unless the next action is trivial and clearly in scope.",
        "```",
        "",
    ]
    (OUT_DIR / "starter-prompts.md").write_text("\n".join(starter_prompts))

    readme = [
        "# Codex Thread Organization",
        "",
        f"This is a safe organization layer for Codex threads. It refreshes sidecar reports and performs only three bounded SQLite maintenance actions: add missing context prefixes to `threads.title`, point each thread `cwd` at `{THREADS_ROOT}/<context>`, and archive stale `archive_candidate` threads.",
        "",
        "## Files",
        "",
        "- `101.md`: start-here guide for using the thread organization system.",
        "- `operating-system.md`: the collaboration model and thread naming rules.",
        "- `workflow-routing.md`: profile routing for `codex-dynamic-workflows`.",
        "- `starter-prompts.md`: prompts for starting, resuming, and closing workflow-shaped threads.",
        "- `queues.md`: operational queues for now, waiting, next, reference, and archive candidates.",
        "- `hourly-dashboard.md`: compact hourly view of recent, changed, waiting, and high-token threads.",
        "- `cleanup-candidates.md`: safe inventory of empty workspaces, legacy dated folders, and archive candidates.",
        "- `thread-index.md`: full human-readable index.",
        "- `thread-index.json`: machine-readable index.",
        "- `thread-index.csv`: spreadsheet-friendly index.",
        "- `suggested-thread-titles.md`: safe rename plan, not applied automatically.",
        "- `last-run-summary.json`: machine-readable summary of the last run.",
        "- `build_thread_organization.py`: regeneration script.",
        "",
        "## Regenerate",
        "",
        "```bash",
        "python3 ~/.codex/thread-organization/build_thread_organization.py",
        "```",
        "",
        "## Hourly Routine",
        "",
        "A local launchd job can run the script hourly. This does not create hourly Codex model threads; it refreshes local sidecar files and applies the bounded maintenance actions above.",
        "",
        "## Safety",
        "",
        "The generated index includes thread IDs, titles, dates, workspace labels, lanes, profiles, and statuses. Generated outputs stay local because they may contain private workflow context.",
        "",
    ]
    (OUT_DIR / "README.md").write_text("\n".join(readme))

    guide_101 = [
        "# Codex Thread Organization 101",
        "",
        "Cette documentation explique comment utiliser l'organisation de threads Codex au quotidien.",
        "",
        "## Idee De Base",
        "",
        "Le systeme garde une couche sidecar lisible et regenerable, et applique une maintenance SQLite limitee pour que l'UI Codex ne garde pas de vieux workspaces en vrac.",
        "",
        "Pourquoi cette approche:",
        "",
        "- elle evite de casser les fichiers internes de Codex;",
        "- elle donne une vue claire des threads actifs, en attente, de reference et a archiver;",
        "- elle route chaque nouveau travail vers le bon profil de subagent;",
        "- elle colle mieux a ta maniere de travailler: objectif clair, execution directe, review stricte, gates CI/PR, prudence ops.",
        "",
        "## Les Fichiers A Connaitre",
        "",
        "Commence ici:",
        "",
        "```text",
        "~/.codex/thread-organization/queues.md",
        "```",
        "",
        "Puis utilise selon le besoin:",
        "",
        "- `queues.md`: vue operationnelle, ce qu'il faut reprendre maintenant ou plus tard.",
        "- `hourly-dashboard.md`: vue compacte des threads recents, bloques, modifies et trop longs.",
        "- `cleanup-candidates.md`: inventaire safe des candidats a archiver ou clarifier.",
        "- `workflow-routing.md`: quelle lane et quel profil utiliser.",
        "- `starter-prompts.md`: prompts prets a coller pour ouvrir/reprendre un thread propre.",
        "- `operating-system.md`: regles generales de collaboration et nommage.",
        "- `thread-index.md`: index complet des threads.",
        "- `suggested-thread-titles.md`: plan de renommage manuel, non applique automatiquement.",
        "",
        "## Les Lanes",
        "",
        "| Lane | Quand l'utiliser | Profil |",
        "| --- | --- | --- |",
        "| `SHIP` | Implementer une issue ou un comportement borne | Issue Implementation Worker |",
        "| `REVIEW` | Auditer code, PR, issues ou commits | PR Review Auditor |",
        "| `GATE` | Suivre CI, PR, reviews, retest, merge readiness | CI / PR Gatekeeper |",
        "| `OPS` | SSH, services, runtime, computer-use, homelab | Ops & Runtime Safety Scout |",
        "| `RESEARCH` | Recherche produit, marche, workflows, decisions | Product / Workflow Research Analyst |",
        "| `SYSTEM` | Codex, prompts, skills, organisation, handoff | Pas de subagent par defaut |",
        "| `LAB` | CAD, 3D, UI prototype, image, exploration creative | Skill domaine d'abord |",
        "| `ARCHIVE` | Termine, stale, doublon, trop petit | Pas de subagent |",
        "",
        "## Routine Quotidienne",
        "",
        "1. Regenerer l'index si beaucoup de threads ont bouge:",
        "",
        "```bash",
        "python3 ~/.codex/thread-organization/build_thread_organization.py",
        "```",
        "",
        "2. Ouvrir `hourly-dashboard.md` pour la vue courte, puis `queues.md` si tu veux reprendre un thread.",
        "",
        "3. Regarder dans cet ordre:",
        "",
        "- `Now`: ce qui merite une reprise ou consolidation rapide.",
        "- `Waiting`: ce qui attend CI, review, retest ou etat externe.",
        "- `Next`: ce qui peut devenir un vrai workflow si repris.",
        "- `Reference`: contexte reusable.",
        "- `Archive Candidates`: a ignorer sauf besoin historique.",
        "",
        "4. Pour un nouveau travail, choisir une lane avant de demarrer.",
        "",
        "5. Copier le prompt correspondant depuis `starter-prompts.md`.",
        "",
        "## Regle Pour Ouvrir Un Nouveau Thread",
        "",
        "Avant de creer un thread, choisir une forme:",
        "",
        "```text",
        "SYSTEM  -> faire le point / router / organiser",
        "SHIP    -> livrer un comportement",
        "REVIEW  -> trouver les problemes",
        "GATE    -> rendre une PR mergeable",
        "OPS     -> diagnostiquer un runtime ou une machine",
        "RESEARCH-> prendre une decision avec evidence",
        "LAB     -> explorer/prototyper",
        "```",
        "",
        "Si le travail contient plusieurs formes, creer un thread parent `SYSTEM`, puis des threads enfants explicites.",
        "",
        "Exemple:",
        "",
        "```text",
        "SYSTEM - <project> - control",
        "SHIP - <project> - issue #8 - sync contacts",
        "REVIEW - <project> - PR #31",
        "GATE - <project> - PR #31 - CI/review",
        "```",
        "",
        "## Quand Utiliser Des Subagents",
        "",
        "Utilise des subagents quand le travail est independant et borne.",
        "",
        "Bon usage:",
        "",
        "- un `explorer` pour auditer une PR pendant que le parent prepare le contexte;",
        "- un `worker` pour modifier un module precis avec ownership clair;",
        "- un `explorer` OPS pour diagnostic read-only avant toute mutation;",
        "- un `explorer` recherche pour cartographier alternatives et evidence.",
        "",
        "Mauvais usage:",
        "",
        "- deleguer la decision bloquante immediate;",
        "- lancer deux agents sur les memes fichiers;",
        "- demander a un subagent de merge/push/force-push;",
        "- confier a un subagent une tache floue comme \"ameliore tout\".",
        "",
        "## Prompt De Base",
        "",
        "Structure a utiliser quand tu veux un thread propre:",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: <SHIP|REVIEW|GATE|OPS|RESEARCH|SYSTEM|LAB>.",
        "Profile: <profile name or none>.",
        "Objective: <one concrete outcome>.",
        "Out of scope: <what not to touch>.",
        "Validation: <commands, checks, sources, or artifacts>.",
        "Delegation: <allowed subagents and ownership>.",
        "Stop condition: <evidence done or blocked handoff>.",
        "```",
        "",
        "## Exemple: Implementer Une Issue",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: SHIP.",
        "Profile: Issue Implementation Worker.",
        "Objective: implement issue #8 only.",
        "Out of scope: unrelated refactors, unrelated features, push/merge.",
        "Validation: targeted tests first, then lint/typecheck/relevant suite.",
        "Delegation: one worker only if files/modules are disjoint; parent integrates.",
        "Stop condition: behavior implemented and verified, or blocked with evidence.",
        "```",
        "",
        "## Exemple: Review Une PR",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: REVIEW.",
        "Profile: PR Review Auditor.",
        "Objective: review PR #31 for real bugs, regressions, security risks, drift, and missing tests.",
        "Out of scope: fixing code.",
        "Validation: findings must reference files/lines or exact behavior surfaces.",
        "Delegation: spawn explorers by concern if broad.",
        "Stop condition: prioritized findings or explicit no-actionable-findings.",
        "```",
        "",
        "## Exemple: Suivre Une PR Jusqu'au Merge",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: GATE.",
        "Profile: CI / PR Gatekeeper.",
        "Objective: determine whether PR #31 is merge-ready and handle only direct blockers.",
        "Out of scope: unrelated cleanup, force-push, merge unless explicitly authorized.",
        "Validation: authoritative CI/PR state, named failed checks/logs, retest after fixes.",
        "Delegation: explorer first; worker only for a narrow fix.",
        "Stop condition: ready, not ready, blocked, or unknown with evidence.",
        "```",
        "",
        "## Exemple: Diagnostic Ops",
        "",
        "```text",
        "Use codex-dynamic-workflows.",
        "Lane: OPS.",
        "Profile: Ops & Runtime Safety Scout.",
        "Objective: diagnose why <service> is failing on <target>.",
        "Out of scope: restarts, upgrades, deletes, migrations, secrets, prod data without approval.",
        "Validation: read-only command evidence, assumptions marked, rollback for any proposed mutation.",
        "Delegation: read-only explorer first.",
        "Stop condition: diagnosis, safe next steps, risk gates, rollback, verification commands.",
        "```",
        "",
        "## Fermer Un Thread",
        "",
        "Avant d'abandonner ou de finir un thread, demander:",
        "",
        "```text",
        "Close out this thread.",
        "Produce: final state, files/artifacts changed, validation evidence, remaining risks, follow-up thread lane if any.",
        "Do not start new work unless the next action is trivial and clearly in scope.",
        "```",
        "",
        "## Regles Simples",
        "",
        "- Un thread long sans lane devient vite confus.",
        "- Un thread `SHIP` doit livrer un comportement, pas discuter du produit.",
        "- Un thread `REVIEW` ne doit pas corriger sauf bascule explicite vers `SHIP`.",
        "- Un thread `GATE` ne doit pas faire de refactor opportuniste.",
        "- Un thread `OPS` commence read-only.",
        "- Un thread `RESEARCH` doit finir par une decision, un MVP, ou des kill criteria.",
        "- Le parent integre; les subagents produisent des packets bornes.",
        "",
        "## Ce Que Le Systeme Ne Fait Pas",
        "",
        "- Il ne renomme pas librement les threads Codex; il ajoute seulement un prefixe de contexte manquant comme `[portfolio]`, `[etabli]`, `[codex]` ou `[archive]`.",
        f"- Il ne modifie pas la base SQLite de Codex hors de `threads.title`, de la normalisation de `threads.cwd` vers `{THREADS_ROOT}/<context>`, et de l'archivage des `archive_candidate`; il sauvegarde avant changement.",
        "- Il ne supprime pas les anciens threads.",
        "- Il ne remplace pas ton jugement: il donne une carte et des rails.",
        "",
        "## Maintenance",
        "",
        "Regenerer apres une grosse session Codex:",
        "",
        "```bash",
        "python3 ~/.codex/thread-organization/build_thread_organization.py",
        "```",
        "",
        "Puis relire:",
        "",
        "```text",
        "~/.codex/thread-organization/queues.md",
        "```",
        "",
        "Si une classification est mauvaise, corriger `build_thread_organization.py`, regenerer, puis verifier `queues.md`.",
        "",
    ]
    (OUT_DIR / "101.md").write_text("\n".join(guide_101))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc)
    previous_state = load_previous_state()
    title_prefix_result = ensure_context_title_prefixes(generated_at)
    rows = load_threads()
    items = enrich(rows)
    auto_archive_result = auto_archive_candidates(items, generated_at)
    if auto_archive_result["changed"]:
        rows = load_threads()
        items = enrich(rows)
    cwd_normalization_result = normalize_thread_cwds(generated_at)
    if cwd_normalization_result["changed"]:
        rows = load_threads()
        items = enrich(rows)
    inventory = workspace_inventory()
    write_json(items)
    write_csv(items)
    write_index_md(items)
    write_queues(items)
    write_rename_plan(items)
    write_system_docs(items)
    write_hourly_dashboard(
        items,
        inventory,
        previous_state,
        generated_at,
        title_prefix_result,
        cwd_normalization_result,
        auto_archive_result,
    )
    write_cleanup_report(items, inventory, generated_at)
    write_generated_views_readme(generated_at)
    write_run_summary_json(
        items,
        inventory,
        previous_state,
        generated_at,
        title_prefix_result,
        cwd_normalization_result,
        auto_archive_result,
    )
    write_automation_memory(
        items,
        inventory,
        previous_state,
        generated_at,
        title_prefix_result,
        cwd_normalization_result,
        auto_archive_result,
    )
    write_run_state(items, generated_at)
    print(
        f"{generated_iso(generated_at)} threads={len(items)} "
        f"now={count_by(items, 'status').get('now', 0)} "
        f"waiting={count_by(items, 'status').get('waiting', 0)} "
        f"reference={count_by(items, 'status').get('reference', 0)} "
        f"title_prefix_changed={title_prefix_result['changed']} "
        f"cwd_normalized={cwd_normalization_result['changed']} "
        f"auto_archived={auto_archive_result['changed']}"
    )


if __name__ == "__main__":
    main()
