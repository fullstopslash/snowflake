#!/usr/bin/env python3
"""
Correlation repair for vikunja-sync.

Ensures syncall's correlation database includes all items that exist in both
Taskwarrior and Vikunja/CalDAV. Prevents "Item already has UUID" errors by
pre-creating TW tasks for orphaned CalDAV items.
"""

import os
import re
import sys
import tempfile
from pathlib import Path

import caldav

from vikunja_common import TaskwarriorClient, SyncLogger


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
                match = re.match(
                    r"\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):\s+"
                    r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
                    line,
                    re.IGNORECASE
                )
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

    # Atomic write: write to temp file, then rename
    fd, temp_path = tempfile.mkstemp(dir=filepath.parent, prefix=".tmp_", suffix=".yaml")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.rename(temp_path, filepath)
    except Exception:
        # Clean up temp file on failure
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise


def repair(
    project: str,
    caldav_url: str,
    caldav_user: str,
    caldav_pass: str,
    tw: TaskwarriorClient,
    logger: SyncLogger,
) -> int:
    """Repair correlations for a project. Returns count of new correlations."""
    config_dir = Path.home() / ".config" / "syncall"
    correlation_file = config_dir / f"{project}____{project}__.yaml"

    tw_tasks = tw.export_project(project)
    tw_by_uuid = {t["uuid"]: t for t in tw_tasks if "uuid" in t}

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
        for tw_uuid, tw_task in tw_by_uuid.items():
            if tw_task.get("description", "") == summary:
                tw_match = tw_uuid
                break

        if tw_match:
            # Found existing TW task
            if tw_match not in updated:
                # TW task not yet correlated - link it
                updated[tw_match] = caldav_uid
                new_count += 1
                logger.info(f"Linked existing TW task to CalDAV: {summary[:30]}")
            else:
                # TW task already correlated to different CalDAV UID - this is a duplicate
                duplicates_to_delete.append((caldav_uid, summary))
        else:
            # Create new TW task
            is_completed = item["status"] == "COMPLETED"
            new_uuid = tw.add_task(summary, project=project)
            if new_uuid:
                if is_completed:
                    tw.complete_task(new_uuid)
                updated[new_uuid] = caldav_uid
                new_count += 1
                status = " (completed)" if is_completed else ""
                logger.info(f"Created TW task{status}: {summary[:30]}")

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
                                logger.info(f"Deleting duplicate CalDAV item: {dup_summary[:30]}")
                                todo.delete()
                    break
        except Exception as e:
            logger.warning(f"Failed to delete duplicates: {e}")

    if new_count > 0:
        save_correlations(correlation_file, updated)
        logger.info(f"Added {new_count} correlations for '{project}'")

    return new_count


def main():
    logger = SyncLogger("correlate")

    if len(sys.argv) != 4:
        print("Usage: correlate.py <project> <caldav_url> <user>", file=sys.stderr)
        print("Set CALDAV_PASSWORD environment variable", file=sys.stderr)
        sys.exit(1)

    project, caldav_url, user = sys.argv[1:4]
    password = os.environ.get("CALDAV_PASSWORD")
    if not password:
        logger.error("CALDAV_PASSWORD environment variable not set")
        sys.exit(1)

    tw = TaskwarriorClient()

    try:
        repair(project, caldav_url, user, password, tw, logger)
    except Exception as e:
        logger.error(f"Correlation repair failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
