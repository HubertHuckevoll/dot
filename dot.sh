#!/bin/bash
# dot.sh — wrapper for dotgen container

set -euo pipefail

COMMAND="${1:-}"
BLOGDIR="${2:-}"
THEMEDIR="${3:-$HOME/dot/theme}"
PUBLISHDIR="${BLOGDIR}.published"

BLOGDIR=$(realpath "$BLOGDIR")
PUBLISHDIR=$(realpath "$PUBLISHDIR" 2>/dev/null || echo "$PUBLISHDIR")
THEMEDIR=$(realpath "$THEMEDIR")

podman run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$BLOGDIR:/mnt/blog:Z" \
  -v "$PUBLISHDIR:/mnt/published:Z" \
  -v "$THEMEDIR:/mnt/theme:Z" \
  dotgen "$COMMAND" /mnt/blog /mnt/published /mnt/theme "${@:3}"
