#!/usr/bin/env python3
"""
Direct CalDAV sync for Taskwarrior.

Provides instant TW -> CalDAV sync by writing directly to the CalDAV server
instead of running full sync. For CalDAV -> TW direction, use periodic sync
(CalDAV doesn't support webhooks).

Target latency: <200ms for single-task push
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
from uuid import uuid4

import caldav
from icalendar import Calendar, Todo

# Prevent hook loops
TW_ENV = {**os.environ, "SYNCALL_RUNNING": "1"}


def log(msg: str) -> None:
    """Log to stderr with timestamp."""
    ts = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
    print(f"[{ts}] {msg}", file=sys.stderr)


@dataclass(slots=True)
class CalDAVConfig:
    """CalDAV connection configuration."""

    url: str
    username: str
    password: str
    calendar_name: str

    @classmethod
    def from_env(cls, target: str = "") -> CalDAVConfig:
        """Load configuration from environment variables."""
        prefix = f"CALDAV_{target.upper()}_" if target else "CALDAV_"

        url = os.environ.get(f"{prefix}URL", "")
        username = os.environ.get(f"{prefix}USER", "")
        calendar = os.environ.get(f"{prefix}CALENDAR", "Tasks")

        # Password from file
        pass_file = os.environ.get(f"{prefix}PASS_FILE", "")
        if pass_file and Path(pass_file).exists():
            password = Path(pass_file).read_text().strip()
        else:
            password = os.environ.get(f"{prefix}PASS", "")

        if not url or not username or not password:
            raise ValueError(f"Missing CalDAV configuration (prefix: {prefix})")

        return cls(
            url=url,
            username=username,
            password=password,
            calendar_name=calendar,
        )


class CalDAVClient:
    """CalDAV client with connection reuse."""

    def __init__(self, config: CalDAVConfig) -> None:
        self._config = config
        self._client: caldav.DAVClient | None = None
        self._calendar: caldav.Calendar | None = None

    @property
    def client(self) -> caldav.DAVClient:
        if self._client is None:
            self._client = caldav.DAVClient(
                url=self._config.url,
                username=self._config.username,
                password=self._config.password,
                timeout=10,  # 10s timeout for network operations
            )
        return self._client

    @property
    def calendar(self) -> caldav.Calendar | None:
        if self._calendar is None:
            try:
                principal = self.client.principal()
                for cal in principal.calendars():
                    if cal.name == self._config.calendar_name:
                        self._calendar = cal
                        break
            except Exception as e:
                log(f"Failed to get calendar: {e}")
        return self._calendar

    def find_todo_by_uid(self, uid: str) -> caldav.Todo | None:
        """Find a TODO by UID."""
        if not self.calendar:
            return None
        try:
            # Try direct URL access first (faster)
            todo_url = f"{self.calendar.url}{uid}.ics"
            todo = caldav.Todo(client=self.client, url=todo_url)
            # Verify it exists by fetching
            todo.load()
            # Verify we got actual data
            if todo.data:
                return todo
        except Exception:
            pass

        # Fallback: search all todos
        try:
            for todo in self.calendar.todos(include_completed=True):
                vtodo = todo.vobject_instance.vtodo
                if hasattr(vtodo, "uid") and vtodo.uid.value == uid:
                    return todo
        except Exception:
            pass
        return None

    def create_todo(self, vcal: Calendar) -> str | None:
        """Create a new TODO and return its UID."""
        if not self.calendar:
            log("No calendar available")
            return None
        try:
            todo = self.calendar.save_todo(vcal.to_ical().decode())
            # Extract UID from the saved TODO
            if hasattr(todo, "vobject_instance") and hasattr(todo.vobject_instance, "vtodo"):
                return todo.vobject_instance.vtodo.uid.value
            return None
        except Exception as e:
            log(f"Failed to create TODO: {e}")
            return None

    def update_todo(self, todo: caldav.Todo, vcal: Calendar) -> bool:
        """Update an existing TODO."""
        try:
            # Set parent calendar if not set (needed for manual Todo objects)
            if not hasattr(todo, 'parent') or todo.parent is None:
                todo.parent = self.calendar
            todo.data = vcal.to_ical().decode()
            todo.save()
            return True
        except Exception as e:
            log(f"Failed to update TODO: {e}")
            return False

    def delete_todo(self, todo: caldav.Todo) -> bool:
        """Delete a TODO."""
        try:
            todo.delete()
            return True
        except Exception as e:
            log(f"Failed to delete TODO: {e}")
            return False


def parse_target_arg(args: list[str]) -> str:
    """Extract --target value from args list."""
    if "--target" in args:
        idx = args.index("--target")
        if idx + 1 < len(args):
            return args[idx + 1]
    return ""


def parse_tw_datetime(dt_str: str) -> datetime | None:
    """Parse Taskwarrior datetime format (YYYYMMDDTHHMMSSZ)."""
    try:
        return datetime.strptime(dt_str, "%Y%m%dT%H%M%SZ")
    except ValueError:
        return None


def tw_to_vtodo(tw_task: dict, existing_uid: str | None = None) -> Calendar:
    """Convert Taskwarrior task to iCalendar VTODO."""
    cal = Calendar()
    cal.add("prodid", "-//caldav-direct//Taskwarrior Sync//EN")
    cal.add("version", "2.0")

    todo = Todo()

    # UID - use existing or generate from TW UUID
    if existing_uid:
        todo.add("uid", existing_uid)
    else:
        tw_uuid = tw_task.get("uuid", str(uuid4()))
        todo.add("uid", tw_uuid)

    # Summary (title)
    todo.add("summary", tw_task.get("description", "Untitled"))

    # Status
    status = tw_task.get("status", "pending")
    if status == "completed":
        todo.add("status", "COMPLETED")
        # Add completion timestamp
        end_dt = parse_tw_datetime(tw_task.get("end", ""))
        todo.add("completed", end_dt or datetime.now(timezone.utc))
    elif status == "deleted":
        todo.add("status", "CANCELLED")
    else:
        todo.add("status", "NEEDS-ACTION")

    # Due date
    due_dt = parse_tw_datetime(tw_task.get("due", ""))
    if due_dt:
        todo.add("due", due_dt)

    # Priority (TW: H/M/L -> iCal: 1-9, lower is higher priority)
    priority = tw_task.get("priority", "")
    if priority == "H":
        todo.add("priority", 1)
    elif priority == "M":
        todo.add("priority", 5)
    elif priority == "L":
        todo.add("priority", 9)

    # Description (notes/annotations)
    annotations = tw_task.get("annotations", [])
    if annotations:
        notes = "\n".join(
            f"{ann.get('entry', '')}: {ann.get('description', '')}"
            for ann in annotations
        )
        todo.add("description", notes)

    # Categories (tags)
    tags = tw_task.get("tags", [])
    if tags:
        todo.add("categories", tags)

    # Timestamps
    now = datetime.now(timezone.utc)
    todo.add("dtstamp", now)

    entry_dt = parse_tw_datetime(tw_task.get("entry", ""))
    todo.add("created", entry_dt or now)

    mod_dt = parse_tw_datetime(tw_task.get("modified", ""))
    if mod_dt:
        todo.add("last-modified", mod_dt)

    cal.add_component(todo)
    return cal


def get_caldav_uid_from_tw(tw_task: dict) -> str | None:
    """Extract CalDAV UID from TW task annotations."""
    for ann in tw_task.get("annotations", []):
        desc = ann.get("description", "")
        # Look for caldav_uid: prefix
        match = re.search(r"caldav_uid:([a-f0-9-]+)", desc, re.IGNORECASE)
        if match:
            return match.group(1)
    # Fallback: use TW UUID as CalDAV UID (syncall convention)
    return tw_task.get("uuid")


def push_task_to_caldav(tw_task: dict, client: CalDAVClient) -> dict:
    """
    Push a Taskwarrior task to CalDAV.

    Returns: {"success": bool, "action": str, "uid": str|None}
    """
    tw_uuid = tw_task.get("uuid", "")
    if not tw_uuid:
        return {"success": False, "action": "no_uuid", "uid": None}

    # Get or create CalDAV UID
    caldav_uid = get_caldav_uid_from_tw(tw_task)

    # Check if TODO already exists
    existing_todo = None
    if caldav_uid:
        existing_todo = client.find_todo_by_uid(caldav_uid)

    # Handle deletion
    if tw_task.get("status") == "deleted":
        if existing_todo:
            if client.delete_todo(existing_todo):
                log(f"Deleted CalDAV TODO: {caldav_uid}")
                return {"success": True, "action": "deleted", "uid": caldav_uid}
            return {"success": False, "action": "delete_failed", "uid": caldav_uid}
        return {"success": True, "action": "already_deleted", "uid": caldav_uid}

    # Create VTODO
    vcal = tw_to_vtodo(tw_task, existing_uid=caldav_uid)

    if existing_todo:
        # Update existing
        if client.update_todo(existing_todo, vcal):
            log(f"Updated CalDAV TODO: {caldav_uid}")
            return {"success": True, "action": "updated", "uid": caldav_uid}
        return {"success": False, "action": "update_failed", "uid": caldav_uid}
    else:
        # Create new
        new_uid = client.create_todo(vcal)
        if new_uid:
            log(f"Created CalDAV TODO: {new_uid}")
            return {"success": True, "action": "created", "uid": new_uid}
        return {"success": False, "action": "create_failed", "uid": None}


def handle_tw_hook(original_json: str, modified_json: str, config: CalDAVConfig) -> dict:
    """
    Handle Taskwarrior on-modify hook.

    Returns: {"success": bool, "action": str, "uid": str|None}
    """
    try:
        tw_task = json.loads(modified_json) if modified_json.strip() else json.loads(original_json)
    except json.JSONDecodeError as e:
        return {"success": False, "action": "json_error", "error": str(e)}

    client = CalDAVClient(config)
    return push_task_to_caldav(tw_task, client)


# =============================================================================
# CLI Entry Points
# =============================================================================


def cmd_push(args: list[str]) -> int:
    """Push a TW task to CalDAV: caldav-direct push <uuid> [--target <name>]"""
    if not args:
        print("Usage: caldav-direct push <uuid> [--target <name>]", file=sys.stderr)
        return 1

    uuid = args[0]
    target = parse_target_arg(args)

    try:
        config = CalDAVConfig.from_env(target)
    except ValueError as e:
        log(f"Config error: {e}")
        return 1

    # Get task from TW
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

        client = CalDAVClient(config)
        push_result = push_task_to_caldav(tasks[0], client)
        print(json.dumps(push_result))
        return 0 if push_result["success"] else 1

    except subprocess.CalledProcessError:
        log(f"Failed to export task {uuid}")
        return 1


def cmd_hook(args: list[str]) -> int:
    """TW hook: reads stdin, outputs task, pushes to CalDAV.

    TW hooks protocol:
    - on-add: receives 1 line (new task JSON), must output 1 line
    - on-modify: receives 2 lines (original, modified), must output 1 line (modified)
    """
    target = parse_target_arg(args)

    lines = sys.stdin.readlines()

    if not lines:
        log("Hook received no input")
        return 1

    # Skip push if we're in a sync (prevent loops)
    skip_push = bool(os.environ.get("SYNCALL_RUNNING"))

    if len(lines) >= 2:
        # on-modify: output the modified task (line 2)
        modified = lines[1].rstrip("\n")
        print(modified)

        if not skip_push:
            try:
                config = CalDAVConfig.from_env(target)
                result = handle_tw_hook(lines[0], modified, config)
                if not result["success"]:
                    log(f"on-modify push failed: {result.get('action', 'unknown')}")
            except ValueError as e:
                log(f"Config error: {e}")
    else:
        # on-add: output the new task AND push to CalDAV
        new_task = lines[0].rstrip("\n")
        print(new_task)

        if not skip_push:
            try:
                config = CalDAVConfig.from_env(target)
                # For on-add, pass new task as first arg, empty as second
                result = handle_tw_hook(new_task, "", config)
                if not result["success"]:
                    log(f"on-add push failed: {result.get('action', 'unknown')}")
            except ValueError as e:
                log(f"Config error: {e}")

    return 0


def cmd_test(args: list[str]) -> int:
    """Test CalDAV connection: caldav-direct test [--target <name>]"""
    target = parse_target_arg(args)

    try:
        config = CalDAVConfig.from_env(target)
        log(f"Testing connection to {config.url}")

        client = CalDAVClient(config)
        if client.calendar:
            log(f"Connected! Calendar: {client.calendar.name}")
            todos = list(client.calendar.todos(include_completed=False))
            log(f"Found {len(todos)} active TODOs")
            return 0
        else:
            log("Failed to find calendar")
            return 1
    except Exception as e:
        log(f"Connection failed: {e}")
        return 1


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: caldav-direct <push|hook|test> [args...]", file=sys.stderr)
        print("  push <uuid> [--target <name>]  - Push TW task to CalDAV", file=sys.stderr)
        print("  hook [--target <name>]         - TW on-modify hook", file=sys.stderr)
        print("  test [--target <name>]         - Test CalDAV connection", file=sys.stderr)
        return 1

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "push":
        return cmd_push(args)
    elif cmd == "hook":
        return cmd_hook(args)
    elif cmd == "test":
        return cmd_test(args)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
