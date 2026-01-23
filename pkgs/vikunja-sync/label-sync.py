#!/usr/bin/env python3
"""
Vikunja label sync - syncs labels from Vikunja to Taskwarrior tags.

This runs after the main syncall sync to handle labels/tags which syncall
doesn't support natively.
"""

import json
import os
import re
import subprocess
import sys
from urllib.request import Request, urlopen
from urllib.error import URLError


def get_api_token():
    """Get Vikunja API token from file or environment."""
    token_file = os.environ.get("VIKUNJA_API_TOKEN_FILE", "")
    if token_file and os.path.exists(token_file):
        with open(token_file) as f:
            return f.read().strip()
    raise ValueError("VIKUNJA_API_TOKEN_FILE not set or file not found")


def api_get(url: str, token: str) -> dict | list:
    """Make authenticated GET request to Vikunja API."""
    req = Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except URLError as e:
        print(f"API error: {e}", file=sys.stderr)
        return []


def get_all_projects(base_url: str, token: str) -> list[dict]:
    """Fetch all Vikunja projects."""
    projects = api_get(f"{base_url}/api/v1/projects", token)
    return projects if projects else []


def get_project_tasks(base_url: str, token: str, project_id: int) -> list[dict]:
    """Fetch all tasks for a specific project."""
    tasks = api_get(f"{base_url}/api/v1/projects/{project_id}/tasks", token)
    return tasks if tasks else []


def get_vikunja_tasks_with_labels(base_url: str, token: str, project_filter: str | None = None) -> list[dict]:
    """Fetch all Vikunja tasks that have labels, by iterating through projects."""
    projects = get_all_projects(base_url, token)
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

        tasks = get_project_tasks(base_url, token, project_id)
        for task in tasks:
            if task.get("labels") and len(task["labels"]) > 0:
                all_tasks_with_labels.append(task)

    return all_tasks_with_labels


def extract_tw_uuid(description: str) -> str | None:
    """Extract Taskwarrior UUID from task description."""
    if not description:
        return None
    # Look for "uuid: <uuid>" pattern (added during import)
    match = re.search(r"uuid:\s*([a-f0-9-]{36})", description, re.IGNORECASE)
    return match.group(1) if match else None


def get_tw_task(uuid: str) -> dict | None:
    """Get Taskwarrior task by UUID."""
    try:
        result = subprocess.run(
            ["task", uuid, "export"],
            capture_output=True,
            text=True,
            check=True,
            env={**os.environ, "VIKUNJA_SYNC_RUNNING": "1"},
        )
        tasks = json.loads(result.stdout) if result.stdout.strip() else []
        return tasks[0] if tasks else None
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return None


def update_tw_tags(uuid: str, tags: list[str]) -> bool:
    """Update Taskwarrior task tags."""
    if not tags:
        return True

    try:
        # Build tag modification command
        # First remove all existing tags, then add new ones
        tag_args = [f"+{tag}" for tag in tags]
        cmd = ["task", uuid, "modify"] + tag_args

        subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            env={**os.environ, "VIKUNJA_SYNC_RUNNING": "1"},
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to update tags for {uuid}: {e}", file=sys.stderr)
        return False


def sync_labels(base_url: str, project_filter: str | None = None) -> int:
    """
    Sync Vikunja labels to Taskwarrior tags.
    Returns count of tasks updated.
    """
    token = get_api_token()
    # Pass project filter to fetch function for efficiency
    tasks = get_vikunja_tasks_with_labels(base_url, token, project_filter)

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
        tw_task = get_tw_task(tw_uuid)
        if not tw_task:
            continue

        # Get current TW tags
        current_tags = set(tw_task.get("tags", []))
        new_tags = set(vikunja_labels)

        # Only update if tags differ
        if new_tags != current_tags:
            # Merge tags (add new ones, keep existing)
            merged_tags = list(current_tags | new_tags)
            if update_tw_tags(tw_uuid, merged_tags):
                print(f"Updated tags for '{task['title'][:30]}': {merged_tags}")
                updated += 1

    return updated


def main():
    base_url = os.environ.get("VIKUNJA_URL", "https://vikunja.chimera-micro.ts.net")
    project = sys.argv[1] if len(sys.argv) > 1 else None

    try:
        count = sync_labels(base_url, project)
        if count > 0:
            print(f"Updated {count} task(s) with labels")
    except Exception as e:
        print(f"Label sync error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
