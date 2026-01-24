"""Shared utilities for vikunja-sync suite."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

__all__ = [
    "Config",
    "ConfigError",
    "VikunjaClient",
    "TaskwarriorClient",
    "SyncLogger",
]


class ConfigError(Exception):
    """Configuration error."""

    pass


@dataclass
class Config:
    """Configuration for Vikunja sync."""

    vikunja_url: str
    api_token: str
    caldav_user: str
    caldav_password: str | None = None

    @classmethod
    def from_env(cls) -> Config:
        """Load configuration from environment variables."""
        vikunja_url = os.environ.get("VIKUNJA_URL", "").rstrip("/")
        if not vikunja_url:
            raise ConfigError("VIKUNJA_URL environment variable not set")

        # Load API token from file
        token_file = os.environ.get("VIKUNJA_API_TOKEN_FILE")
        if not token_file:
            raise ConfigError("VIKUNJA_API_TOKEN_FILE environment variable not set")

        try:
            api_token = Path(token_file).read_text(encoding="utf-8").strip()
        except (FileNotFoundError, PermissionError) as e:
            raise ConfigError(f"Cannot read token file {token_file}: {e}") from e

        if not api_token:
            raise ConfigError(f"Token file {token_file} is empty")

        caldav_user = os.environ.get("VIKUNJA_USER", "")

        # CalDAV password is optional (only needed for correlate)
        caldav_pass_file = os.environ.get("VIKUNJA_CALDAV_PASS_FILE")
        caldav_password = None
        if caldav_pass_file:
            try:
                caldav_password = Path(caldav_pass_file).read_text(encoding="utf-8").strip()
            except (FileNotFoundError, PermissionError):
                pass  # Optional, ignore errors

        return cls(
            vikunja_url=vikunja_url,
            api_token=api_token,
            caldav_user=caldav_user,
            caldav_password=caldav_password,
        )


class VikunjaClient:
    """HTTP client for Vikunja API."""

    def __init__(
        self,
        config: Config,
        timeout: int = 30,
        max_retries: int = 3,
        logger: SyncLogger | None = None,
    ):
        self.config = config
        self.timeout = timeout
        self.max_retries = max_retries
        self.logger = logger
        self._label_cache: dict[str, int] = {}

    def _request(
        self, method: str, endpoint: str, data: dict | None = None
    ) -> dict | list | None:
        """Make HTTP request with retry on transient failures."""
        url = f"{self.config.vikunja_url}/api/v1{endpoint}"
        headers = {"Authorization": f"Bearer {self.config.api_token}"}

        body = None
        if data is not None:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"

        last_error = None
        for attempt in range(self.max_retries):
            if self.logger and attempt > 0:
                self.logger.retry(
                    f"API request to {endpoint}", attempt + 1, self.max_retries
                )
            req = Request(url, data=body, headers=headers, method=method)
            try:
                with urlopen(req, timeout=self.timeout) as resp:
                    return json.loads(resp.read().decode())
            except HTTPError as e:
                if e.code == 404:
                    return None
                if e.code >= 500:
                    # Server error, retry
                    last_error = e
                    time.sleep(2**attempt)  # 1s, 2s, 4s
                    continue
                raise  # 4xx errors don't retry
            except URLError as e:
                # Connection error, retry
                last_error = e
                time.sleep(2**attempt)
                continue
            except json.JSONDecodeError:
                return None

        # All retries exhausted
        if last_error:
            raise last_error
        return None

    def get(self, endpoint: str) -> dict | list | None:
        """GET request."""
        return self._request("GET", endpoint)

    def put(self, endpoint: str, data: dict) -> dict | None:
        """PUT request."""
        result = self._request("PUT", endpoint, data)
        return result if isinstance(result, dict) else None

    def post(self, endpoint: str, data: dict) -> dict | None:
        """POST request."""
        result = self._request("POST", endpoint, data)
        return result if isinstance(result, dict) else None

    def delete(self, endpoint: str) -> bool:
        """DELETE request. Returns True on success."""
        try:
            self._request("DELETE", endpoint)
            return True
        except HTTPError:
            return False

    def get_labels(self) -> list[dict]:
        """Fetch all labels."""
        result = self.get("/labels")
        return result if isinstance(result, list) else []

    def get_or_create_label(self, title: str) -> int | None:
        """Get existing label ID or create new one. Uses cache."""
        if title in self._label_cache:
            return self._label_cache[title]

        # Populate cache on first call
        if not self._label_cache:
            for label in self.get_labels():
                self._label_cache[label.get("title", "")] = label.get("id")

        if title in self._label_cache:
            return self._label_cache[title]

        # Create new label
        result = self.put("/labels", {"title": title})
        if result and "id" in result:
            self._label_cache[title] = result["id"]
            return result["id"]
        return None

    def attach_label(self, task_id: int, label_id: int) -> bool:
        """Attach label to task."""
        try:
            self.put(f"/tasks/{task_id}/labels", {"label_id": label_id})
            return True
        except HTTPError as e:
            return e.code == 409  # Already attached is OK

    def detach_label(self, task_id: int, label_id: int) -> bool:
        """Detach label from task."""
        return self.delete(f"/tasks/{task_id}/labels/{label_id}")

    def get_task(self, task_id: int) -> dict | None:
        """Get task by ID."""
        result = self.get(f"/tasks/{task_id}")
        return result if isinstance(result, dict) else None

    def clear_label_cache(self) -> None:
        """Clear label cache (call at start of sync operations)."""
        self._label_cache.clear()


class TaskwarriorClient:
    """Client for Taskwarrior CLI operations."""

    SYNC_ENV = {**os.environ, "VIKUNJA_SYNC_RUNNING": "1"}

    def __init__(self, timeout: int = 30):
        self.timeout = timeout

    def _run(
        self, args: list[str], input_text: str | None = None
    ) -> subprocess.CompletedProcess:
        """Run task command with return code checking and timeout."""
        try:
            return subprocess.run(
                ["task", *args],
                input=input_text,
                capture_output=True,
                text=True,
                env=self.SYNC_ENV,
                timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            # Return a fake CompletedProcess with error
            return subprocess.CompletedProcess(
                args=["task", *args],
                returncode=124,  # Standard timeout exit code
                stdout="",
                stderr=f"Command timed out after {self.timeout}s",
            )

    def export_all(self) -> list[dict]:
        """Export all tasks."""
        result = self._run(["export"])
        if result.returncode != 0 or not result.stdout.strip():
            return []
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return []

    def export_project(self, project: str) -> list[dict]:
        """Export tasks from a specific project."""
        result = self._run([f"project:{project}", "export"])
        if result.returncode != 0 or not result.stdout.strip():
            return []
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return []

    def export_task(self, uuid: str) -> dict | None:
        """Export a single task by UUID."""
        result = self._run([uuid, "export"])
        if result.returncode != 0 or not result.stdout.strip():
            return None
        try:
            tasks = json.loads(result.stdout)
            return tasks[0] if tasks else None
        except (json.JSONDecodeError, IndexError):
            return None

    def modify_task(self, uuid: str, **changes) -> bool:
        """Modify a task. Returns True on success."""
        args = [uuid, "modify"]
        for key, value in changes.items():
            if key == "tags_add":
                args.extend(f"+{tag}" for tag in value)
            elif key == "tags_remove":
                args.extend(f"-{tag}" for tag in value)
            elif key == "project":
                args.append(f"project:{value}")
            elif key == "priority":
                args.append(f"priority:{value}")
            elif key == "description":
                args.append(f"description:{value}")
            else:
                args.append(f"{key}:{value}")
        result = self._run(args)
        return result.returncode == 0

    def add_tags(self, uuid: str, tags: list[str]) -> bool:
        """Add tags to a task."""
        if not tags:
            return True
        return self.modify_task(uuid, tags_add=tags)

    def remove_tags(self, uuid: str, tags: list[str]) -> bool:
        """Remove tags from a task."""
        if not tags:
            return True
        return self.modify_task(uuid, tags_remove=tags)

    def delete_task(self, uuid: str) -> bool:
        """Delete a task. Returns True on success."""
        result = self._run([uuid, "delete"], input_text="yes\n")
        return result.returncode == 0

    def complete_task(self, uuid: str) -> bool:
        """Mark a task as done. Returns True on success."""
        result = self._run([uuid, "done"])
        return result.returncode == 0

    def add_task(
        self,
        description: str,
        project: str | None = None,
        tags: list[str] | None = None,
    ) -> str | None:
        """Add a new task. Returns UUID on success."""
        args = ["add", description]
        if project:
            args.append(f"project:{project}")
        if tags:
            args.extend(f"+{tag}" for tag in tags)
        result = self._run(args)
        if result.returncode != 0:
            return None
        # Parse UUID from output (format: "Created task UUID")
        match = re.search(
            r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
            result.stdout,
            re.I,
        )
        return match.group(1) if match else None


class SyncLogger:
    """Structured logger for sync operations."""

    def __init__(self, component: str):
        self.component = component

    def _log(self, level: str, msg: str, **context):
        """Write log entry to stderr."""
        timestamp = datetime.now(timezone.utc).isoformat()
        ctx_str = " ".join(f"{k}={v}" for k, v in context.items()) if context else ""
        entry = f"[{timestamp}] {level} [{self.component}] {msg}"
        if ctx_str:
            entry += f" {ctx_str}"
        print(entry, file=sys.stderr)

    def info(self, msg: str, **context):
        """Log info message."""
        self._log("INFO", msg, **context)

    def warning(self, msg: str, **context):
        """Log warning message."""
        self._log("WARN", msg, **context)

    def error(self, msg: str, **context):
        """Log error message."""
        self._log("ERROR", msg, **context)

    def debug(self, msg: str, **context):
        """Log debug message (only if VIKUNJA_DEBUG is set)."""
        if os.environ.get("VIKUNJA_DEBUG"):
            self._log("DEBUG", msg, **context)

    def retry(self, msg: str, attempt: int, max_attempts: int, **context):
        """Log retry attempt."""
        self._log("WARN", f"{msg} (attempt {attempt}/{max_attempts})", **context)

    def timeout(self, msg: str, seconds: int, **context):
        """Log timeout event."""
        self._log("ERROR", f"{msg} (timed out after {seconds}s)", **context)
