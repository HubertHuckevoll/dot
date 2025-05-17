#!/bin/bash
# Wrapper to run dotgen inside a Podman container

IMAGE_NAME="dotgen"
BLOG_DIR="$(realpath "$1")"
shift

if [ ! -d "$BLOG_DIR" ]; then
  echo "Directory '$BLOG_DIR' does not exist."
  exit 1
fi

podman run --rm \
  -v "$BLOG_DIR":/data:Z \
  "$IMAGE_NAME" "$@" "/data"
