#!/bin/bash
# Wrapper to run dotgen inside a Podman container

IMAGE_NAME="dotgen"

sudo podman run --rm \
  -v "$HOME":"/home/$USER":Z \
  "$IMAGE_NAME" "$@"
