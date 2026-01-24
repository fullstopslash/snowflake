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
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING
from urllib.error import HTTPError, URLError

from vikunja_common import Config, ConfigError, VikunjaClient, TaskwarriorClient

if TYPE_CHECKING:
    from typing import Any


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


def vikunja_repeat_to_tw_recur(repeat_after: int, repeat_mode: int) -> str | None:
    """
    Convert Vikunja repeat_after (seconds) to Taskwarrior recur string.

    Vikunja repeat_after: interval in seconds
    Vikunja repeat_mode: 0 = from due date, 1 = from completion date

    TW recur: daily, weekly, monthly, yearly, or Ndays/Nweeks/Nmonths
    """
    if not repeat_after or repeat_after <= 0:
        return None

    # Common intervals (with some tolerance for rounding)
    day = 86400
    week = 604800
    month = 2592000  # ~30 days
    year = 31536000  # ~365 days

    # Check for exact common intervals first
    if repeat_after == day:
        return "daily"
    elif repeat_after == week:
        return "weekly"
    elif repeat_after == 14 * day:
        return "biweekly"
    elif month - day <= repeat_after <= month + day:
        return "monthly"
    elif 3 * month - day <= repeat_after <= 3 * month + day:
        return "quarterly"
    elif year - day <= repeat_after <= year + day:
        return "yearly"

    # For non-standard intervals, calculate in days/weeks
    days = repeat_after // day
    if days > 0:
        if days % 7 == 0:
            weeks = days // 7
            return f"{weeks}weeks" if weeks > 1 else "weekly"
        return f"{days}days" if days > 1 else "daily"

    # Fallback - just use days even if less than a day
    return "daily"


def tw_recur_to_vikunja_repeat(recur: str) -> tuple[int, int]:
    """
    Convert Taskwarrior recur to Vikunja repeat_after (seconds) and repeat_mode.

    Returns: (repeat_after, repeat_mode)
    repeat_mode: 0 = from due date (default)
    """
    if not recur:
        return (0, 0)

    recur = recur.lower().strip()
    day = 86400
    week = 604800
    month = 2592000
    year = 31536000

    # Named intervals
    named = {
        "daily": day,
        "weekly": week,
        "biweekly": 2 * week,
        "monthly": month,
        "quarterly": 3 * month,
        "semiannual": 6 * month,
        "annual": year,
        "yearly": year,
    }

    if recur in named:
        return (named[recur], 0)

    # Parse Ndays, Nweeks, Nmonths, Nyears
    match = re.match(r"(\d+)\s*(day|week|month|year)s?", recur)
    if match:
        n = int(match.group(1))
        unit = match.group(2)
        multipliers = {"day": day, "week": week, "month": month, "year": year}
        return (n * multipliers.get(unit, day), 0)

    return (0, 0)


# =============================================================================
# Vikunja -> Taskwarrior (webhook handler)
# =============================================================================


def vikunja_to_tw_task(task: dict, project_title: str) -> dict:
    """
    Convert Vikunja task to Taskwarrior JSON format.

    Vikunja fields: id, title, description, done, due_date, start_date, end_date,
                    priority, labels, repeat_after, repeat_mode, etc.
    TW fields: uuid, description, project, status, due, scheduled, until, recur,
               priority, tags, annotations
    """
    tw_task: dict[str, Any] = {
        "description": task.get("title", "Untitled"),
        "project": project_title,
        "status": "completed" if task.get("done") else "pending",
    }

    annotations = []

    # Store Vikunja task ID in annotation for correlation
    vikunja_id = task.get("id")
    if vikunja_id:
        annotations.append({
            "entry": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
            "description": f"vikunja_id:{vikunja_id}",
        })

    # Store Vikunja description (body text) as annotation if non-empty
    vikunja_desc = task.get("description", "")
    if vikunja_desc and vikunja_desc.strip():
        # Prefix to identify it as the body text
        annotations.append({
            "entry": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
            "description": f"note:{vikunja_desc.strip()[:500]}",  # Limit length
        })

    if annotations:
        tw_task["annotations"] = annotations

    # Due date (Vikunja uses ISO format, TW uses YYYYMMDDTHHMMSSZ)
    due_dt = parse_iso_datetime(task.get("due_date", ""))
    if due_dt:
        tw_task["due"] = due_dt.strftime("%Y%m%dT%H%M%SZ")

    # Start date -> scheduled
    start_dt = parse_iso_datetime(task.get("start_date", ""))
    if start_dt:
        tw_task["scheduled"] = start_dt.strftime("%Y%m%dT%H%M%SZ")

    # End date -> until
    end_dt = parse_iso_datetime(task.get("end_date", ""))
    if end_dt:
        tw_task["until"] = end_dt.strftime("%Y%m%dT%H%M%SZ")

    # Recurrence (repeat_after + repeat_mode -> recur)
    repeat_after = task.get("repeat_after", 0)
    repeat_mode = task.get("repeat_mode", 0)
    if repeat_after:
        recur = vikunja_repeat_to_tw_recur(repeat_after, repeat_mode)
        if recur:
            tw_task["recur"] = recur

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


def find_tw_task_by_vikunja_id(tw: TaskwarriorClient, vikunja_id: int) -> str | None:
    """Find Taskwarrior task UUID by Vikunja ID annotation."""
    tasks = tw.export_all()
    for task in tasks:
        for ann in task.get("annotations", []):
            if f"vikunja_id:{vikunja_id}" in ann.get("description", ""):
                return task.get("uuid")
    return None


def find_tw_task_by_description(tw: TaskwarriorClient, description: str, project: str) -> str | None:
    """Find TW task by exact description match in project."""
    tasks = tw.export_project(project)
    for task in tasks:
        if task.get("description") == description:
            return task.get("uuid")
    return None


def handle_webhook(payload: dict) -> dict:
    """
    Handle Vikunja webhook payload - direct write to Taskwarrior.

    Returns: {"success": bool, "action": str, "uuid": str|None}
    """
    tw = TaskwarriorClient()

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
        existing_uuid = find_tw_task_by_vikunja_id(tw, vikunja_id)
    if not existing_uuid and title:
        existing_uuid = find_tw_task_by_description(tw, title, project_title)

    if event == "task.deleted":
        if existing_uuid:
            if tw.delete_task(existing_uuid):
                log(f"Deleted TW task: {existing_uuid}")
                return {"success": True, "action": "deleted", "uuid": existing_uuid}
            else:
                log(f"Failed to delete TW task {existing_uuid}")
                return {"success": False, "action": "delete_failed", "uuid": existing_uuid}
        return {"success": True, "action": "delete_skipped", "uuid": None}

    elif event in ("task.created", "task.updated"):
        tw_task = vikunja_to_tw_task(task, project_title)

        if existing_uuid:
            # Update existing task
            existing_task = tw.export_task(existing_uuid)

            # Build modification changes
            changes: dict[str, Any] = {}

            # Sync description (title) changes
            if tw_task.get("description") and existing_task:
                if tw_task["description"] != existing_task.get("description"):
                    changes["description"] = tw_task["description"]

            # Sync due date
            if "due" in tw_task:
                changes["due"] = tw_task["due"]
            elif existing_task and existing_task.get("due"):
                # Due was removed in Vikunja
                changes["due"] = ""

            # Sync priority
            if "priority" in tw_task:
                changes["priority"] = tw_task["priority"]
            elif existing_task and existing_task.get("priority"):
                # Priority was removed in Vikunja
                changes["priority"] = ""

            # Sync scheduled (start_date)
            if "scheduled" in tw_task:
                changes["scheduled"] = tw_task["scheduled"]
            elif existing_task and existing_task.get("scheduled"):
                # Start date was removed in Vikunja
                changes["scheduled"] = ""

            # Sync until (end_date)
            if "until" in tw_task:
                changes["until"] = tw_task["until"]
            elif existing_task and existing_task.get("until"):
                # End date was removed in Vikunja
                changes["until"] = ""

            # Sync recurrence (note: TW doesn't allow removing recur from recurring tasks)
            if "recur" in tw_task:
                changes["recur"] = tw_task["recur"]
            # Don't try to clear recurrence - TW will reject it for recurring tasks

            # Compute tag diff: add new tags, remove old tags
            current_tw_tags = set(existing_task.get("tags", [])) if existing_task else set()
            new_tags_from_vikunja = set(tw_task.get("tags", []))

            tags_to_add = list(new_tags_from_vikunja - current_tw_tags)
            tags_to_remove = list(current_tw_tags - new_tags_from_vikunja)

            if tags_to_add:
                changes["tags_add"] = tags_to_add
            if tags_to_remove:
                changes["tags_remove"] = tags_to_remove

            if changes:
                if not tw.modify_task(existing_uuid, **changes):
                    log(f"Failed to modify TW task {existing_uuid}")
                    return {"success": False, "action": "modify_failed", "uuid": existing_uuid}

            # Handle completion status
            if tw_task["status"] == "completed":
                if not tw.complete_task(existing_uuid):
                    log(f"Failed to mark TW task {existing_uuid} done")
                    return {"success": False, "action": "done_failed", "uuid": existing_uuid}

            log(f"Updated TW task: {existing_uuid}")
            return {"success": True, "action": "updated", "uuid": existing_uuid}
        else:
            # Create new task via import (keeping direct subprocess for import)
            import_json = json.dumps([tw_task])
            log(f"Importing task: {import_json[:200]}")

            result = subprocess.run(
                ["task", "import"],
                input=import_json,
                capture_output=True,
                text=True,
                env=TaskwarriorClient.SYNC_ENV,
            )

            if result.returncode != 0:
                log(f"Import failed (code {result.returncode}): stdout={result.stdout[:200]}, stderr={result.stderr[:200]}")
                return {"success": False, "action": "create_failed", "uuid": None}

            # Extract UUID from import output
            match = re.search(r"([a-f0-9-]{36})", result.stdout + result.stderr)
            new_uuid = match.group(1) if match else None

            log(f"Created TW task: {new_uuid or 'unknown'}")
            return {"success": True, "action": "created", "uuid": new_uuid}

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
    else:
        # Clear due date if not set
        vikunja_task["due_date"] = None

    # Scheduled -> start_date
    scheduled_dt = parse_tw_datetime(tw_task.get("scheduled", ""))
    if scheduled_dt:
        vikunja_task["start_date"] = scheduled_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    else:
        vikunja_task["start_date"] = None

    # Until -> end_date
    until_dt = parse_tw_datetime(tw_task.get("until", ""))
    if until_dt:
        vikunja_task["end_date"] = until_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    else:
        vikunja_task["end_date"] = None

    # Recurrence (TW recur -> Vikunja repeat_after/repeat_mode)
    recur = tw_task.get("recur", "")
    if recur:
        repeat_after, repeat_mode = tw_recur_to_vikunja_repeat(recur)
        if repeat_after > 0:
            vikunja_task["repeat_after"] = repeat_after
            vikunja_task["repeat_mode"] = repeat_mode
    else:
        # Clear recurrence if not set
        vikunja_task["repeat_after"] = 0

    # Priority (TW: H/M/L -> Vikunja: 1-5)
    priority = tw_task.get("priority", "")
    if priority == "H":
        vikunja_task["priority"] = 5
    elif priority == "M":
        vikunja_task["priority"] = 3
    elif priority == "L":
        vikunja_task["priority"] = 1
    else:
        vikunja_task["priority"] = 0

    return vikunja_task


def get_vikunja_task_id_from_tw(tw_task: dict) -> int | None:
    """Extract Vikunja task ID from TW annotations."""
    for ann in tw_task.get("annotations", []):
        match = re.search(r"vikunja_id:(\d+)", ann.get("description", ""))
        if match:
            return int(match.group(1))
    return None


def get_or_create_project(vikunja: VikunjaClient, project_title: str) -> int | None:
    """Get existing project ID or create new project."""
    # Get all projects
    projects = vikunja.get("/projects")
    if isinstance(projects, list):
        for p in projects:
            if p.get("title") == project_title:
                return p.get("id")

    # Create new project
    result = vikunja.put("/projects", {"title": project_title})
    if result and "id" in result:
        log(f"Created Vikunja project: {project_title} (ID: {result['id']})")
        return result["id"]
    return None


def find_vikunja_task_by_title(vikunja: VikunjaClient, project_id: int, title: str) -> int | None:
    """Find Vikunja task by title in project."""
    tasks = vikunja.get(f"/projects/{project_id}/tasks")
    if isinstance(tasks, list):
        for t in tasks:
            if t.get("title") == title:
                return t.get("id")
    return None


def push_to_vikunja(tw_task: dict, config: Config, default_project: str = "inbox") -> dict:
    """
    Push a Taskwarrior task to Vikunja API.

    Returns: {"success": bool, "action": str, "vikunja_id": int|None}
    """
    vikunja = VikunjaClient(config)

    project_title = tw_task.get("project", "") or default_project

    # Get or create project in Vikunja
    project_id = get_or_create_project(vikunja, project_title)
    if not project_id:
        log(f"Failed to get/create project '{project_title}' in Vikunja")
        return {"success": False, "action": "project_error", "vikunja_id": None}

    vikunja_task = tw_to_vikunja_task(tw_task)

    # Get label IDs for TW tags (will attach after task create/update)
    tw_tags = tw_task.get("tags", [])
    label_ids = []
    for tag in tw_tags:
        label_id = vikunja.get_or_create_label(tag)
        if label_id:
            label_ids.append(label_id)

    vikunja_id = get_vikunja_task_id_from_tw(tw_task)

    # Try to find by title if no ID annotation
    if not vikunja_id:
        vikunja_id = find_vikunja_task_by_title(vikunja, project_id, tw_task.get("description", ""))

    try:
        if vikunja_id:
            # Update existing task
            result = vikunja.post(f"/tasks/{vikunja_id}", vikunja_task)
            if result:
                log(f"Updated Vikunja task: {vikunja_id}")
                task_id = vikunja_id
                action = "updated"
            else:
                return {"success": False, "action": "api_error", "vikunja_id": vikunja_id}
        else:
            # Create new task
            vikunja_task["project_id"] = project_id
            result = vikunja.put(f"/projects/{project_id}/tasks", vikunja_task)
            if result and "id" in result:
                task_id = result["id"]
                log(f"Created Vikunja task: {task_id}")
                action = "created"
            else:
                return {"success": False, "action": "create_failed", "vikunja_id": None}

        # Detach labels that are no longer in TW tags (only for updates)
        if action == "updated" and task_id:
            current_vikunja_task = vikunja.get_task(task_id)
            if current_vikunja_task:
                current_labels = current_vikunja_task.get("labels") or []
                current_label_titles = {label["title"] for label in current_labels}
                new_label_titles = set(tw_task.get("tags", []))
                labels_to_remove = current_label_titles - new_label_titles

                # Build a map of title -> id for removal
                label_title_to_id = {label["title"]: label["id"] for label in current_labels}

                for title in labels_to_remove:
                    label_id = label_title_to_id.get(title)
                    if label_id:
                        vikunja.detach_label(task_id, label_id)

                if labels_to_remove:
                    log(f"Detached {len(labels_to_remove)} label(s) from task {task_id}")

        # Attach labels to task
        if label_ids and task_id:
            for label_id in label_ids:
                vikunja.attach_label(task_id, label_id)
            log(f"Attached {len(label_ids)} label(s) to task {task_id}")

        return {"success": True, "action": action, "vikunja_id": task_id}

    except HTTPError as e:
        log(f"Vikunja API error: {e.code} {e.reason}")
        return {"success": False, "action": "api_error", "vikunja_id": vikunja_id}
    except URLError as e:
        log(f"Network error: {e}")
        return {"success": False, "action": "network_error", "vikunja_id": vikunja_id}


def delete_from_vikunja(tw_task: dict, config: Config, default_project: str = "inbox") -> dict:
    """
    Delete a task from Vikunja.

    Returns: {"success": bool, "action": str, "vikunja_id": int|None}
    """
    vikunja = VikunjaClient(config)

    vikunja_id = get_vikunja_task_id_from_tw(tw_task)

    if not vikunja_id:
        # Try to find by title if no ID annotation
        project_title = tw_task.get("project", "") or default_project
        if project_title:
            project_id = get_or_create_project(vikunja, project_title)
            if project_id:
                vikunja_id = find_vikunja_task_by_title(
                    vikunja, project_id, tw_task.get("description", "")
                )

    if not vikunja_id:
        log(f"No Vikunja task found for TW task: {tw_task.get('uuid', 'unknown')}")
        return {"success": True, "action": "not_found", "vikunja_id": None}

    try:
        result = vikunja.delete(f"/tasks/{vikunja_id}")
        if result:
            log(f"Deleted Vikunja task: {vikunja_id}")
            return {"success": True, "action": "deleted", "vikunja_id": vikunja_id}
        else:
            # delete() returns False on HTTPError (including 404)
            # Treat as success since the task is gone either way
            log(f"Vikunja task {vikunja_id} delete returned False (may already be deleted)")
            return {"success": True, "action": "possibly_deleted", "vikunja_id": vikunja_id}

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
    except ConfigError as e:
        return {"success": False, "action": "config_error", "error": str(e)}

    # Default project for tasks without a project (configurable via env)
    default_project = os.environ.get("VIKUNJA_DEFAULT_PROJECT", "inbox")

    try:
        # modified_json contains the task after changes
        if modified_json.strip():
            tw_task = json.loads(modified_json)
        elif added_json.strip():
            tw_task = json.loads(added_json)
        else:
            return {"success": False, "action": "no_input"}

        return push_to_vikunja(tw_task, config, default_project)

    except json.JSONDecodeError as e:
        return {"success": False, "action": "json_error", "error": str(e)}


def handle_tw_delete_hook(task_json: str) -> dict:
    """
    Handle Taskwarrior on-delete hook.

    TW on-delete hook receives: task JSON on stdin (single line).
    We delete the task from Vikunja.
    """
    try:
        config = Config.from_env()
    except ConfigError as e:
        return {"success": False, "action": "config_error", "error": str(e)}

    # Default project for tasks without a project (configurable via env)
    default_project = os.environ.get("VIKUNJA_DEFAULT_PROJECT", "inbox")

    try:
        tw_task = json.loads(task_json)
        return delete_from_vikunja(tw_task, config, default_project)

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
    tw = TaskwarriorClient()

    task = tw.export_task(uuid)
    if not task:
        log(f"Task {uuid} not found")
        return 1

    try:
        config = Config.from_env()
        default_project = os.environ.get("VIKUNJA_DEFAULT_PROJECT", "inbox")
        push_result = push_to_vikunja(task, config, default_project)
        print(json.dumps(push_result))
        return 0 if push_result["success"] else 1

    except ConfigError as e:
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


def cmd_delete_hook(_args: list[str]) -> int:
    """TW on-delete hook: reads stdin, outputs task, deletes from Vikunja.

    TW on-delete hook protocol:
    - receives 1 line (task JSON being deleted), must output 1 line (same task)
    """
    lines = sys.stdin.readlines()

    if not lines:
        log("Delete hook received no input")
        return 1

    # Output the task (required by TW hook protocol)
    task_json = lines[0].rstrip("\n")
    print(task_json)

    # Skip delete if we're in a sync (prevent loops)
    if os.environ.get("VIKUNJA_SYNC_RUNNING"):
        return 0

    result = handle_tw_delete_hook(task_json)
    if not result["success"]:
        log(f"on-delete failed: {result.get('action', 'unknown')}")

    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: vikunja-direct <webhook|push|hook|delete-hook> [args...]", file=sys.stderr)
        print("  webhook [file]  - Handle Vikunja webhook payload", file=sys.stderr)
        print("  push <uuid>     - Push TW task to Vikunja", file=sys.stderr)
        print("  hook            - TW on-add/on-modify hook (stdin)", file=sys.stderr)
        print("  delete-hook     - TW on-delete hook (stdin)", file=sys.stderr)
        return 1

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "webhook":
        return cmd_webhook(args)
    elif cmd == "push":
        return cmd_push(args)
    elif cmd == "hook":
        return cmd_hook(args)
    elif cmd == "delete-hook":
        return cmd_delete_hook(args)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
