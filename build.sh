#!/bin/bash
# Build the dotgen container using Podman

IMAGE_NAME="dotgen"
sudo podman build -t "$IMAGE_NAME" .
