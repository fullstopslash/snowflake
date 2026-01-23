#!/usr/bin/env python3
"""
Correlation repair for vikunja-sync.

Ensures syncall's correlation database includes all items that exist in both
Taskwarrior and Vikunja/CalDAV. Prevents "Item already has UUID" errors by
pre-creating TW tasks for orphaned CalDAV items.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

import caldav


def get_tw_tasks(project: str) -> dict[str, dict]:
    """Get Taskwarrior tasks for a project. Returns {uuid: task_dict}."""
    try:
        result = subprocess.run(
            ["task", f"project:{project}", "export"],
            capture_output=True,
            text=True,
            check=True,
            env={**os.environ, "VIKUNJA_SYNC_RUNNING": "1"},
        )
        tasks = json.loads(result.stdout) if result.stdout.strip() else []
        return {t["uuid"]: t for t in tasks if "uuid" in t}
    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Warning: Failed to get TW tasks: {e}", file=sys.stderr)
        return {}


def get_caldav_items(url: str, user: str, passwd: str, calendar: str) -> dict[str, dict]:
    """Get CalDAV items from a calendar. Returns {uid: {summary, status}}."""
    try:
        client = caldav.DAVClient(url=url, username=user, password=passwd)
        principal = client.principal()

        for cal in principal.calendars():
            if cal.name == calendar:
                items = {}
                for todo in cal.todos(include_completed=True):
                    vtodo = todo.vobject_instance.vtodo
                    uid = vtodo.uid.value
                    summary_obj = getattr(vtodo, "summary", None)
                    status_obj = getattr(vtodo, "status", None)
                    items[uid] = {
                        "summary": summary_obj.value if summary_obj else "",
                        "status": status_obj.value if status_obj else "NEEDS-ACTION",
                    }
                return items

        print(f"Warning: Calendar '{calendar}' not found", file=sys.stderr)
        return {}
    except Exception as e:
        print(f"Warning: Failed to get CalDAV items: {e}", file=sys.stderr)
        return {}


def load_correlations(filepath: Path) -> dict[str, str]:
    """Load existing correlations. Returns {tw_uuid: caldav_uid}."""
    if not filepath.exists():
        return {}

    try:
        with open(filepath) as f:
            content = f.read()

        # Parse UUID mappings directly with regex (avoids bidict YAML issues)
        result = {}
        in_fwdm = False
        for line in content.split("\n"):
            if "_fwdm:" in line:
                in_fwdm = True
                continue
            if in_fwdm:
                if "_inv:" in line or "_invm:" in line:
                    break
                match = re.match(r"\s+([a-f0-9-]+):\s+([a-f0-9-]+)", line)
                if match:
                    result[match.group(1)] = match.group(2)
        return result
    except Exception as e:
        print(f"Warning: Failed to load correlations: {e}", file=sys.stderr)
        return {}


def save_correlations(filepath: Path, correlations: dict[str, str]) -> None:
    """Save correlations in syncall's bidict YAML format."""
    inverse = {v: k for k, v in correlations.items()}

    def fmt(mapping: dict, indent: int) -> str:
        if not mapping:
            return " " * indent + "{}"
        lines = [f"{' ' * indent}{k}: {v}" for k, v in sorted(mapping.items())]
        return "\n".join(lines)

    content = f"""Tw_caldav_ids: !!python/object:bidict.bidict
  _fwdm: &id001
{fmt(correlations, 4)}
  _inv: !!python/object:bidict.bidict
    _fwdm: &id002
{fmt(inverse, 6)}
    _inv: null
    _invm: *id001
  _invm: *id002
"""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w") as f:
        f.write(content)


def create_tw_task(project: str, description: str, completed: bool = False) -> str | None:
    """Create a TW task and return its UUID."""
    env = {**os.environ, "VIKUNJA_SYNC_RUNNING": "1"}
    try:
        cmd = ["task", "add", f"project:{project}", description]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, env=env)

        # Extract task ID from "Created task 123."
        match = re.search(r"Created task (\d+)", result.stdout)
        if not match:
            return None

        task_id = match.group(1)

        # Get UUID using task export
        export = subprocess.run(
            ["task", task_id, "export"],
            capture_output=True, text=True, check=True, env=env,
        )
        tasks = json.loads(export.stdout) if export.stdout.strip() else []
        if not tasks:
            return None

        uuid = tasks[0].get("uuid")
        if completed and uuid:
            subprocess.run(["task", uuid, "done"], capture_output=True, check=True, env=env)
        return uuid
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to create TW task: {e}", file=sys.stderr)
        return None


def repair(project: str, caldav_url: str, caldav_user: str, caldav_pass: str) -> int:
    """Repair correlations for a project. Returns count of new correlations."""
    config_dir = Path.home() / ".config" / "syncall"
    correlation_file = config_dir / f"{project}____{project}__.yaml"

    tw_tasks = get_tw_tasks(project)
    caldav_items = get_caldav_items(caldav_url, caldav_user, caldav_pass, project)

    if not caldav_items:
        return 0

    existing = load_correlations(correlation_file)
    existing_caldav_uids = set(existing.values())

    # Find CalDAV items that aren't correlated (orphaned items from Vikunja)
    orphaned_caldav = {
        uid: item for uid, item in caldav_items.items()
        if uid not in existing_caldav_uids
    }

    if not orphaned_caldav:
        return 0

    new_count = 0
    updated = dict(existing)

    # Track duplicates to delete
    duplicates_to_delete = []

    # Create TW tasks for orphaned CalDAV items
    for caldav_uid, item in orphaned_caldav.items():
        summary = item["summary"]
        if not summary:
            continue

        # Check if TW already has a task with same description (by content match)
        tw_match = None
        for tw_uuid, tw_task in tw_tasks.items():
            if tw_task.get("description", "") == summary:
                tw_match = tw_uuid
                break

        if tw_match:
            # Found existing TW task
            if tw_match not in updated:
                # TW task not yet correlated - link it
                updated[tw_match] = caldav_uid
                new_count += 1
                print(f"Linked existing TW task to CalDAV: {summary[:30]}")
            else:
                # TW task already correlated to different CalDAV UID - this is a duplicate
                duplicates_to_delete.append((caldav_uid, summary))
        else:
            # Create new TW task
            is_completed = item["status"] == "COMPLETED"
            new_uuid = create_tw_task(project, summary, completed=is_completed)
            if new_uuid:
                updated[new_uuid] = caldav_uid
                new_count += 1
                status = " (completed)" if is_completed else ""
                print(f"Created TW task{status}: {summary[:30]}")

    # Delete duplicate CalDAV items
    if duplicates_to_delete:
        try:
            client = caldav.DAVClient(url=caldav_url, username=caldav_user, password=caldav_pass)
            principal = client.principal()
            for cal in principal.calendars():
                if cal.name == project:
                    for todo in cal.todos(include_completed=True):
                        uid = todo.vobject_instance.vtodo.uid.value
                        for dup_uid, dup_summary in duplicates_to_delete:
                            if uid == dup_uid:
                                print(f"Deleting duplicate CalDAV item: {dup_summary[:30]}")
                                todo.delete()
                    break
        except Exception as e:
            print(f"Warning: Failed to delete duplicates: {e}", file=sys.stderr)

    if new_count > 0:
        save_correlations(correlation_file, updated)
        print(f"Added {new_count} correlations for '{project}'")

    return new_count


def main():
    if len(sys.argv) < 5:
        print(
            "Usage: correlate.py <project> <url> <user> <pass>",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        repair(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
