#!/bin/bash
# Wrapper to run dotgen inside a Podman container

set -e

CMD="$1"
BLOGDIR="$2"
PUBLISHDIR="${BLOGDIR}.published"

# Optional third argument (theme)
THEMEDIR="${3:-$HOME/dot/theme}"

# Wenn der Befehl "init" ist, müssen BLOGDIR und PUBLISHDIR existieren
if [[ "$CMD" == "init" ]]; then
  mkdir -p "$BLOGDIR" "$PUBLISHDIR"
fi

# Aufruf des Containers
sudo podman run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$BLOGDIR":/mnt/blog:z \
  -v "$PUBLISHDIR":/mnt/published:z \
  -v "$THEMEDIR":/mnt/theme:ro,z \
  dotgen "$@"
