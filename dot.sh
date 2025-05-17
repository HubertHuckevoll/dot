#!/bin/bash
# Wrapper to run dotgen inside a Podman container

podman run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$HOME:/home/$USER":Z \
  -w "/home/$USER" \
  dotgen "$@"
