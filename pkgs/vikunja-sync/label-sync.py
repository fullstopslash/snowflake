#!/usr/bin/env python3
"""
Vikunja label sync - syncs labels from Vikunja to Taskwarrior tags.

This runs after the main syncall sync to handle labels/tags which syncall
doesn't support natively.
"""

import re
import sys

from vikunja_common import Config, ConfigError, VikunjaClient, TaskwarriorClient, SyncLogger


def extract_tw_uuid(description: str) -> str | None:
    """Extract Taskwarrior UUID from task description."""
    if not description:
        return None
    # Look for "uuid: <uuid>" pattern (added during import)
    match = re.search(
        r"uuid:\s*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
        description,
        re.IGNORECASE
    )
    return match.group(1) if match else None


def get_vikunja_tasks_with_labels(
    vikunja: VikunjaClient, project_filter: str | None = None
) -> list[dict]:
    """Fetch all Vikunja tasks that have labels, by iterating through projects."""
    projects = vikunja.get("/projects")
    if not projects:
        return []

    all_tasks_with_labels = []
    for project in projects:
        # Skip if project filter specified and doesn't match
        if project_filter and project.get("title") != project_filter:
            continue

        project_id = project.get("id")
        if not project_id:
            continue

        tasks = vikunja.get(f"/projects/{project_id}/tasks")
        if tasks:
            for task in tasks:
                if task.get("labels") and len(task["labels"]) > 0:
                    all_tasks_with_labels.append(task)

    return all_tasks_with_labels


def sync_labels(
    vikunja: VikunjaClient,
    tw: TaskwarriorClient,
    logger: SyncLogger,
    project_filter: str | None = None,
) -> int:
    """
    Sync Vikunja labels to Taskwarrior tags.
    Returns count of tasks updated.
    """
    tasks = get_vikunja_tasks_with_labels(vikunja, project_filter)

    if not tasks:
        return 0

    updated = 0
    for task in tasks:
        # Extract TW UUID from description
        tw_uuid = extract_tw_uuid(task.get("description", ""))
        if not tw_uuid:
            continue

        # Get label titles
        vikunja_labels = [label["title"] for label in task.get("labels", [])]
        if not vikunja_labels:
            continue

        # Get current TW task
        tw_task = tw.export_task(tw_uuid)
        if not tw_task:
            continue

        # Get current TW tags
        current_tags = set(tw_task.get("tags", []))
        new_tags = set(vikunja_labels)

        # Only update if there are new tags to add
        tags_to_add = new_tags - current_tags
        if tags_to_add:
            if tw.add_tags(tw_uuid, list(tags_to_add)):
                merged = list(current_tags | new_tags)
                logger.info(f"Updated tags for '{task['title'][:30]}': {merged}")
                updated += 1

    return updated


def main():
    logger = SyncLogger("label-sync")

    try:
        config = Config.from_env()
    except ConfigError as e:
        logger.error(str(e))
        sys.exit(1)

    vikunja = VikunjaClient(config)
    tw = TaskwarriorClient()

    project = sys.argv[1] if len(sys.argv) > 1 else None

    try:
        count = sync_labels(vikunja, tw, logger, project)
        if count > 0:
            logger.info(f"Updated {count} task(s) with labels")
    except Exception as e:
        logger.error(f"Label sync error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
