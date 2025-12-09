#!/usr/bin/env bash
set -euo pipefail

# Launch CCS GUI inside the container using X11 forwarding.
# Requirements on host: X server running, and allow local docker connections.
# Usage:
#   scripts/run_x11.sh [IMAGE_TAG] [WORKSPACE_DIR] [PROJECTS_DIR] [PRODUCTS_DIR]
# Defaults:
#   IMAGE_TAG: whuzfb/ccstudio:latest
#   WORKSPACE_DIR: $HOME/ccs-workspace

IMAGE_TAG="${1:-whuzfb/ccstudio:latest}"
WORKSPACE_DIR_DEFAULT="$HOME/ccs-workspace"
WORKSPACE_DIR="${2:-$WORKSPACE_DIR_DEFAULT}"
PROJECTS_DIR="${3:-}"
PRODUCTS_DIR="${4:-${PRODUCTS_DIR:-}}"

mkdir -p "$WORKSPACE_DIR"

if ! command -v xhost >/dev/null 2>&1; then
  echo "xhost not found. Install x11-xserver-utils (sudo apt install x11-xserver-utils)." >&2
  exit 1
fi

# Allow local docker to access X server (temporary; session-scoped)
xhost +local:docker >/dev/null 2>&1 || true

DOCKER_ARGS=(
  --rm -it
  --name ccs-x11
  -e DISPLAY="${DISPLAY}"
  -e QT_X11_NO_MITSHM=1
  -e TZ="${TZ:-Etc/UTC}"
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro
  -v "$WORKSPACE_DIR":/workspaces
)

# Optional: mount a projects dir if you want CLI builds too
# Optional: mount a projects dir if provided or detected
if [[ -n "$PROJECTS_DIR" ]]; then
  DOCKER_ARGS+=( -v "$PROJECTS_DIR:/ccs_projects" )
elif [[ -d "./ccs_projects" ]]; then
  DOCKER_ARGS+=( -v "$(pwd)/ccs_projects:/ccs_projects" )
fi

# Optional: mount additional TI products (e.g., Processor SDK RTOS) into /opt/ti/products/
if [[ -n "$PRODUCTS_DIR" ]]; then
  DOCKER_ARGS+=( -v "$PRODUCTS_DIR:/root/ti/products/" )
fi

echo "Starting container '${IMAGE_TAG}' with X11 forwarding..."
# Override entrypoint to avoid CLI build script and launch GUI directly
docker run --entrypoint "" "${DOCKER_ARGS[@]}" "${IMAGE_TAG}" bash -lc \
  "/opt/ti/ccs/eclipse/ccstudio -data /workspaces"

# Revoke access when exiting (best-effort)
xhost -local:docker >/dev/null 2>&1 || true
