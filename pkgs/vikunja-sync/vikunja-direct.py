#!/usr/bin/env python3
"""
Direct-write sync for Vikunja <-> Taskwarrior.

Eliminates full-sync overhead by:
1. Parsing webhook payload directly (no re-fetch)
2. Writing to Taskwarrior via JSON import
3. Pushing TW changes directly to Vikunja API

Target latency: <100ms for single-task operations.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

if TYPE_CHECKING:
    from typing import Any

# Prevent hook loops
TW_ENV = {**os.environ, "VIKUNJA_SYNC_RUNNING": "1"}


@dataclass(slots=True)
class Config:
    """Sync configuration loaded from environment."""

    vikunja_url: str
    api_token: str
    caldav_user: str

    @classmethod
    def from_env(cls) -> Config:
        url = os.environ.get("VIKUNJA_URL", "")
        if not url:
            raise ValueError("VIKUNJA_URL not set")

        token_file = os.environ.get("VIKUNJA_API_TOKEN_FILE", "")
        if token_file and Path(token_file).exists():
            token = Path(token_file).read_text().strip()
        else:
            raise ValueError("VIKUNJA_API_TOKEN_FILE not set or not found")

        user = os.environ.get("VIKUNJA_USER", "")
        if not user:
            raise ValueError("VIKUNJA_USER not set")

        return cls(
            vikunja_url=url.rstrip("/"),
            api_token=token,
            caldav_user=user,
        )


def log(msg: str) -> None:
    """Log to stderr with timestamp."""
    ts = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
    print(f"[{ts}] {msg}", file=sys.stderr)


def parse_tw_datetime(dt_str: str) -> datetime | None:
    """Parse Taskwarrior datetime format (YYYYMMDDTHHMMSSZ)."""
    try:
        return datetime.strptime(dt_str, "%Y%m%dT%H%M%SZ")
    except ValueError:
        return None


def parse_iso_datetime(dt_str: str) -> datetime | None:
    """Parse ISO datetime format from Vikunja."""
    if not dt_str or dt_str == "0001-01-01T00:00:00Z":
        return None
    try:
        return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
    except ValueError:
        return None


# =============================================================================
# Vikunja -> Taskwarrior (webhook handler)
# =============================================================================


def vikunja_to_tw_task(task: dict, project_title: str) -> dict:
    """
    Convert Vikunja task to Taskwarrior JSON format.

    Vikunja fields: id, title, description, done, due_date, priority, labels, etc.
    TW fields: uuid, description, project, status, due, priority, tags, annotations
    """
    tw_task: dict[str, Any] = {
        "description": task.get("title", "Untitled"),
        "project": project_title,
        "status": "completed" if task.get("done") else "pending",
    }

    # Store Vikunja task ID in annotation for correlation
    vikunja_id = task.get("id")
    if vikunja_id:
        tw_task["annotations"] = [
            {
                "entry": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
                "description": f"vikunja_id:{vikunja_id}",
            }
        ]

    # Due date (Vikunja uses ISO format, TW uses YYYYMMDDTHHMMSSZ)
    due_dt = parse_iso_datetime(task.get("due_date", ""))
    if due_dt:
        tw_task["due"] = due_dt.strftime("%Y%m%dT%H%M%SZ")

    # Priority (Vikunja: 1-5, TW: H/M/L)
    priority = task.get("priority", 0)
    if priority >= 4:
        tw_task["priority"] = "H"
    elif priority >= 2:
        tw_task["priority"] = "M"
    elif priority >= 1:
        tw_task["priority"] = "L"

    # Labels -> Tags
    labels = task.get("labels", [])
    if labels:
        tw_task["tags"] = [label.get("title", "") for label in labels if label.get("title")]

    return tw_task


def find_tw_task_by_vikunja_id(vikunja_id: int) -> str | None:
    """Find Taskwarrior task UUID by Vikunja ID annotation."""
    try:
        result = subprocess.run(
            ["task", "export"],
            capture_output=True,
            text=True,
            check=True,
            env=TW_ENV,
        )
        tasks = json.loads(result.stdout) if result.stdout.strip() else []

        for task in tasks:
            for ann in task.get("annotations", []):
                if f"vikunja_id:{vikunja_id}" in ann.get("description", ""):
                    return task.get("uuid")
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        pass
    return None


def find_tw_task_by_description(description: str, project: str) -> str | None:
    """Find TW task by exact description match in project."""
    try:
        result = subprocess.run(
            ["task", f"project:{project}", "export"],
            capture_output=True,
            text=True,
            check=True,
            env=TW_ENV,
        )
        tasks = json.loads(result.stdout) if result.stdout.strip() else []

        for task in tasks:
            if task.get("description") == description:
                return task.get("uuid")
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        pass
    return None


def handle_webhook(payload: dict) -> dict:
    """
    Handle Vikunja webhook payload - direct write to Taskwarrior.

    Returns: {"success": bool, "action": str, "uuid": str|None}
    """
    event = payload.get("event_name", "")
    data = payload.get("data", {})
    task = data.get("task", {})
    project = data.get("project", {}) or task.get("project", {})
    project_title = project.get("title", "")

    if not task or not project_title:
        return {"success": False, "action": "invalid_payload", "uuid": None}

    vikunja_id = task.get("id")
    title = task.get("title", "")

    # Try to find existing TW task
    existing_uuid = None
    if vikunja_id:
        existing_uuid = find_tw_task_by_vikunja_id(vikunja_id)
    if not existing_uuid and title:
        existing_uuid = find_tw_task_by_description(title, project_title)

    if event == "task.deleted":
        if existing_uuid:
            try:
                subprocess.run(
                    ["task", existing_uuid, "delete"],
                    input="yes\n",
                    capture_output=True,
                    text=True,
                    env=TW_ENV,
                )
                log(f"Deleted TW task: {existing_uuid}")
                return {"success": True, "action": "deleted", "uuid": existing_uuid}
            except subprocess.CalledProcessError:
                pass
        return {"success": True, "action": "delete_skipped", "uuid": None}

    elif event in ("task.created", "task.updated"):
        tw_task = vikunja_to_tw_task(task, project_title)

        if existing_uuid:
            # Update existing task
            try:
                args = ["task", existing_uuid, "modify"]

                if "due" in tw_task:
                    args.append(f"due:{tw_task['due']}")
                if "priority" in tw_task:
                    args.append(f"priority:{tw_task['priority']}")
                if tw_task.get("tags"):
                    args.extend(f"+{tag}" for tag in tw_task["tags"])

                subprocess.run(args, capture_output=True, text=True, env=TW_ENV)

                # Handle completion status
                if tw_task["status"] == "completed":
                    subprocess.run(
                        ["task", existing_uuid, "done"],
                        capture_output=True,
                        env=TW_ENV,
                    )

                log(f"Updated TW task: {existing_uuid}")
                return {"success": True, "action": "updated", "uuid": existing_uuid}
            except subprocess.CalledProcessError as e:
                log(f"Failed to update task: {e}")
                return {"success": False, "action": "update_failed", "uuid": existing_uuid}
        else:
            # Create new task via import
            try:
                import_json = json.dumps([tw_task])
                log(f"Importing task: {import_json[:200]}")

                result = subprocess.run(
                    ["task", "import"],
                    input=import_json,
                    capture_output=True,
                    text=True,
                    env=TW_ENV,
                )

                if result.returncode != 0:
                    log(f"Import failed (code {result.returncode}): stdout={result.stdout[:200]}, stderr={result.stderr[:200]}")
                    return {"success": False, "action": "create_failed", "uuid": None}

                # Extract UUID from import output
                match = re.search(r"([a-f0-9-]{36})", result.stdout + result.stderr)
                new_uuid = match.group(1) if match else None

                log(f"Created TW task: {new_uuid or 'unknown'}")
                return {"success": True, "action": "created", "uuid": new_uuid}
            except subprocess.CalledProcessError as e:
                log(f"Failed to create task (exception): {e}")
                return {"success": False, "action": "create_failed", "uuid": None}

    return {"success": True, "action": "ignored", "uuid": None}


# =============================================================================
# Taskwarrior -> Vikunja (on-exit hook)
# =============================================================================


def tw_to_vikunja_task(tw_task: dict) -> dict:
    """Convert Taskwarrior task to Vikunja API format."""
    vikunja_task: dict[str, Any] = {
        "title": tw_task.get("description", "Untitled"),
        "done": tw_task.get("status") == "completed",
    }

    # Due date
    due_dt = parse_tw_datetime(tw_task.get("due", ""))
    if due_dt:
        vikunja_task["due_date"] = due_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    # Priority (TW: H/M/L -> Vikunja: 1-5)
    priority = tw_task.get("priority", "")
    if priority == "H":
        vikunja_task["priority"] = 5
    elif priority == "M":
        vikunja_task["priority"] = 3
    elif priority == "L":
        vikunja_task["priority"] = 1

    return vikunja_task


# Label cache to avoid repeated API calls within a single sync
_label_cache: dict[str, int] = {}


def get_all_labels(config: Config) -> list[dict]:
    """Fetch all Vikunja labels."""
    try:
        req = Request(
            f"{config.vikunja_url}/api/v1/labels",
            headers={"Authorization": f"Bearer {config.api_token}"},
        )
        with urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except (URLError, json.JSONDecodeError):
        return []


def get_or_create_label(config: Config, title: str) -> int | None:
    """Get existing label ID or create new label. Uses cache for efficiency."""
    # Check cache first
    if title in _label_cache:
        return _label_cache[title]

    # Fetch all labels and populate cache
    if not _label_cache:
        labels = get_all_labels(config)
        for label in labels:
            _label_cache[label.get("title", "")] = label.get("id")

    # Check if label exists now
    if title in _label_cache:
        return _label_cache[title]

    # Create new label
    try:
        req = Request(
            f"{config.vikunja_url}/api/v1/labels",
            data=json.dumps({"title": title}).encode(),
            headers={
                "Authorization": f"Bearer {config.api_token}",
                "Content-Type": "application/json",
            },
            method="PUT",
        )
        with urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read().decode())
            label_id = result.get("id")
            if label_id:
                _label_cache[title] = label_id
                log(f"Created Vikunja label: {title} (ID: {label_id})")
            return label_id
    except (URLError, json.JSONDecodeError, HTTPError) as e:
        log(f"Failed to create label '{title}': {e}")
        return None


def get_vikunja_project_id(config: Config, project_title: str) -> int | None:
    """Get Vikunja project ID by title."""
    try:
        req = Request(
            f"{config.vikunja_url}/api/v1/projects",
            headers={"Authorization": f"Bearer {config.api_token}"},
        )
        with urlopen(req, timeout=10) as resp:
            projects = json.loads(resp.read().decode())
            for p in projects:
                if p.get("title") == project_title:
                    return p.get("id")
    except (URLError, json.JSONDecodeError):
        pass
    return None


def create_vikunja_project(config: Config, project_title: str) -> int | None:
    """Create a new Vikunja project and return its ID."""
    try:
        req = Request(
            f"{config.vikunja_url}/api/v1/projects",
            data=json.dumps({"title": project_title}).encode(),
            headers={
                "Authorization": f"Bearer {config.api_token}",
                "Content-Type": "application/json",
            },
            method="PUT",
        )
        with urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read().decode())
            project_id = result.get("id")
            log(f"Created Vikunja project: {project_title} (ID: {project_id})")
            return project_id
    except (URLError, json.JSONDecodeError, HTTPError) as e:
        log(f"Failed to create project: {e}")
        return None


def get_or_create_vikunja_project(config: Config, project_title: str) -> int | None:
    """Get existing project ID or create new project."""
    project_id = get_vikunja_project_id(config, project_title)
    if project_id:
        return project_id
    return create_vikunja_project(config, project_title)


def get_vikunja_task_id_from_tw(tw_task: dict) -> int | None:
    """Extract Vikunja task ID from TW annotations."""
    for ann in tw_task.get("annotations", []):
        match = re.search(r"vikunja_id:(\d+)", ann.get("description", ""))
        if match:
            return int(match.group(1))
    return None


def find_vikunja_task_by_title(
    config: Config, project_id: int, title: str
) -> int | None:
    """Find Vikunja task by title in project."""
    try:
        req = Request(
            f"{config.vikunja_url}/api/v1/projects/{project_id}/tasks",
            headers={"Authorization": f"Bearer {config.api_token}"},
        )
        with urlopen(req, timeout=10) as resp:
            tasks = json.loads(resp.read().decode())
            for t in tasks:
                if t.get("title") == title:
                    return t.get("id")
    except (URLError, json.JSONDecodeError):
        pass
    return None


def push_to_vikunja(tw_task: dict, config: Config) -> dict:
    """
    Push a Taskwarrior task to Vikunja API.

    Returns: {"success": bool, "action": str, "vikunja_id": int|None}
    """
    project_title = tw_task.get("project", "")
    if not project_title:
        return {"success": False, "action": "no_project", "vikunja_id": None}

    # Get or create project in Vikunja
    project_id = get_or_create_vikunja_project(config, project_title)
    if not project_id:
        log(f"Failed to get/create project '{project_title}' in Vikunja")
        return {"success": False, "action": "project_error", "vikunja_id": None}

    vikunja_task = tw_to_vikunja_task(tw_task)

    # Get label IDs for TW tags (will attach after task create/update)
    tw_tags = tw_task.get("tags", [])
    label_ids = []
    for tag in tw_tags:
        label_id = get_or_create_label(config, tag)
        if label_id:
            label_ids.append(label_id)

    vikunja_id = get_vikunja_task_id_from_tw(tw_task)

    # Try to find by title if no ID annotation
    if not vikunja_id:
        vikunja_id = find_vikunja_task_by_title(
            config, project_id, tw_task.get("description", "")
        )

    try:
        if vikunja_id:
            # Update existing task
            req = Request(
                f"{config.vikunja_url}/api/v1/tasks/{vikunja_id}",
                data=json.dumps(vikunja_task).encode(),
                headers={
                    "Authorization": f"Bearer {config.api_token}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode())
                log(f"Updated Vikunja task: {vikunja_id}")
                task_id = vikunja_id
                action = "updated"
        else:
            # Create new task
            vikunja_task["project_id"] = project_id
            req = Request(
                f"{config.vikunja_url}/api/v1/projects/{project_id}/tasks",
                data=json.dumps(vikunja_task).encode(),
                headers={
                    "Authorization": f"Bearer {config.api_token}",
                    "Content-Type": "application/json",
                },
                method="PUT",
            )
            with urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode())
                task_id = result.get("id")
                log(f"Created Vikunja task: {task_id}")
                action = "created"

        # Attach labels to task via separate API calls
        if label_ids and task_id:
            for label_id in label_ids:
                try:
                    req = Request(
                        f"{config.vikunja_url}/api/v1/tasks/{task_id}/labels",
                        data=json.dumps({"label_id": label_id}).encode(),
                        headers={
                            "Authorization": f"Bearer {config.api_token}",
                            "Content-Type": "application/json",
                        },
                        method="PUT",
                    )
                    with urlopen(req, timeout=10):
                        pass  # Success
                except HTTPError as e:
                    # 409 Conflict means label already attached, that's fine
                    if e.code != 409:
                        log(f"Failed to attach label {label_id}: {e.code}")

            log(f"Attached {len(label_ids)} label(s) to task {task_id}")

        return {"success": True, "action": action, "vikunja_id": task_id}

    except HTTPError as e:
        log(f"Vikunja API error: {e.code} {e.reason}")
        return {"success": False, "action": "api_error", "vikunja_id": vikunja_id}
    except URLError as e:
        log(f"Network error: {e}")
        return {"success": False, "action": "network_error", "vikunja_id": vikunja_id}


def handle_tw_hook(added_json: str, modified_json: str) -> dict:
    """
    Handle Taskwarrior on-modify hook.

    TW hooks receive: original task JSON on line 1, modified task JSON on line 2.
    We push the modified task to Vikunja.
    """
    try:
        config = Config.from_env()
    except ValueError as e:
        return {"success": False, "action": "config_error", "error": str(e)}

    try:
        # modified_json contains the task after changes
        if modified_json.strip():
            tw_task = json.loads(modified_json)
        elif added_json.strip():
            tw_task = json.loads(added_json)
        else:
            return {"success": False, "action": "no_input"}

        return push_to_vikunja(tw_task, config)

    except json.JSONDecodeError as e:
        return {"success": False, "action": "json_error", "error": str(e)}


# =============================================================================
# CLI Entry Points
# =============================================================================


def cmd_webhook(args: list[str]) -> int:
    """Handle webhook: vikunja-direct webhook [payload-file | -]"""
    if args and args[0] not in ("-", ""):
        payload_str = Path(args[0]).read_text()
    else:
        # Read from stdin
        payload_str = sys.stdin.read()

    try:
        payload = json.loads(payload_str)
    except json.JSONDecodeError as e:
        log(f"Invalid JSON payload: {e}")
        return 1

    result = handle_webhook(payload)
    print(json.dumps(result))
    return 0 if result["success"] else 1


def cmd_push(args: list[str]) -> int:
    """Push TW task to Vikunja: vikunja-direct push <uuid>"""
    if not args:
        print("Usage: vikunja-direct push <uuid>", file=sys.stderr)
        return 1

    uuid = args[0]

    try:
        result = subprocess.run(
            ["task", uuid, "export"],
            capture_output=True,
            text=True,
            check=True,
            env=TW_ENV,
        )
        tasks = json.loads(result.stdout) if result.stdout.strip() else []
        if not tasks:
            log(f"Task {uuid} not found")
            return 1

        config = Config.from_env()
        push_result = push_to_vikunja(tasks[0], config)
        print(json.dumps(push_result))
        return 0 if push_result["success"] else 1

    except subprocess.CalledProcessError:
        log(f"Failed to export task {uuid}")
        return 1
    except ValueError as e:
        log(f"Config error: {e}")
        return 1


def cmd_hook(_args: list[str]) -> int:
    """TW hook: reads stdin, outputs task, pushes to Vikunja.

    TW hooks protocol:
    - on-add: receives 1 line (new task JSON), must output 1 line
    - on-modify: receives 2 lines (original, modified), must output 1 line (modified)
    """
    lines = sys.stdin.readlines()

    if not lines:
        log("Hook received no input")
        return 1

    # Skip push if we're in a sync (prevent loops)
    skip_push = bool(os.environ.get("VIKUNJA_SYNC_RUNNING"))

    if len(lines) >= 2:
        # on-modify: output the modified task (line 2)
        modified = lines[1].rstrip("\n")
        print(modified)

        if not skip_push:
            result = handle_tw_hook(lines[0], modified)
            if not result["success"]:
                log(f"on-modify push failed: {result.get('action', 'unknown')}")
    else:
        # on-add: output the new task AND push to Vikunja
        new_task = lines[0].rstrip("\n")
        print(new_task)

        if not skip_push:
            # For on-add, pass new task as first arg, empty as second
            result = handle_tw_hook(new_task, "")
            if not result["success"]:
                log(f"on-add push failed: {result.get('action', 'unknown')}")

    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: vikunja-direct <webhook|push|hook> [args...]", file=sys.stderr)
        print("  webhook [file]  - Handle Vikunja webhook payload", file=sys.stderr)
        print("  push <uuid>     - Push TW task to Vikunja", file=sys.stderr)
        print("  hook            - TW on-modify hook (stdin)", file=sys.stderr)
        return 1

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "webhook":
        return cmd_webhook(args)
    elif cmd == "push":
        return cmd_push(args)
    elif cmd == "hook":
        return cmd_hook(args)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
