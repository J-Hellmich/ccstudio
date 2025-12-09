#!/usr/bin/env bash
set -euo pipefail

# Enter a running CCS container with an interactive shell.
# Usage:
#   scripts/enter_container.sh [CONTAINER_NAME]
# Defaults:
#   CONTAINER_NAME: ccs-x11
# If the container is not running, a helpful message is printed.

CONTAINER_NAME="${1:-ccs-x11}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Please install Docker and ensure it's on PATH." >&2
  exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  echo "Container '$CONTAINER_NAME' is not running. Start it first (e.g., make run-x11-gui)." >&2
  exit 1
fi

# Exec into the container
exec docker exec -it "$CONTAINER_NAME" bash
