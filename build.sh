#!/bin/bash
# Build the dotgen container using Podman

IMAGE_NAME="dotgen"
podman build -t "$IMAGE_NAME" .
