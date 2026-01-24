#!/usr/bin/env python3
"""Process the vikunja-sync retry queue."""
import sys
from pathlib import Path
from vikunja_common import SyncLogger

QUEUE_FILE = Path("/tmp/vikunja-sync-queue.txt")


def main():
    logger = SyncLogger("retry")

    if not QUEUE_FILE.exists():
        logger.debug("No queue file, nothing to retry")
        return 0

    # Read and deduplicate UUIDs
    try:
        content = QUEUE_FILE.read_text()
        uuids = list(dict.fromkeys(line.strip() for line in content.splitlines() if line.strip()))
    except Exception as e:
        logger.error(f"Failed to read queue: {e}")
        return 1

    if not uuids:
        logger.debug("Queue empty")
        QUEUE_FILE.unlink(missing_ok=True)
        return 0

    logger.info(f"Processing {len(uuids)} queued task(s)")

    import subprocess

    failed = []
    for uuid in uuids:
        result = subprocess.run(
            ["vikunja-direct", "push", uuid],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            logger.warning(f"Retry failed for {uuid}: {result.stderr}")
            failed.append(uuid)
        else:
            logger.info(f"Retry succeeded for {uuid}")

    # Write back only failed UUIDs
    if failed:
        QUEUE_FILE.write_text("\n".join(failed) + "\n")
        logger.warning(f"{len(failed)} task(s) still failing")
    else:
        QUEUE_FILE.unlink(missing_ok=True)
        logger.info("Queue cleared")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
