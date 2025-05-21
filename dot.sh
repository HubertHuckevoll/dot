#!/bin/bash
# dot.sh - Fully containerized dotgen wrapper

set -euo pipefail

IMAGE="dotgen"
CMD="$1"
BLOGDIR="$(realpath "$2")"
BLOGNAME="$(basename "$BLOGDIR")"
THEMEDIR="$(realpath "${3:-$HOME/dot/theme}")"
TMP_CONTAINER_ID=""

# Create a temporary container
TMP_CONTAINER_ID=$(podman create "$IMAGE" "$CMD" "/mnt/blog" "${@:3}")

# Copy blog into container (if it exists)
if [[ -d "$BLOGDIR" ]]; then
  podman cp "$BLOGDIR" "$TMP_CONTAINER_ID:/mnt/blog"
fi

# Copy theme into container if it exists and command is `build`
if [[ "$CMD" == "build" && -d "$THEMEDIR" ]]; then
  podman cp "$THEMEDIR" "$TMP_CONTAINER_ID:/mnt/theme"
fi

# Start container
podman start -a "$TMP_CONTAINER_ID"

# Copy blog folder back from container
rm -rf "$BLOGDIR"
podman cp "$TMP_CONTAINER_ID:/mnt/blog" "$BLOGDIR"

# Copy published folder back if it was generated
if [[ "$CMD" == "build" ]]; then
  rm -rf "${BLOGDIR}.published"
  podman cp "$TMP_CONTAINER_ID:/mnt/published" "${BLOGDIR}.published"
fi

# Clean up container
podman rm "$TMP_CONTAINER_ID"
