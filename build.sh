#!/bin/bash
# Build the dotgen container using Podman

IMAGE_NAME="dotgen"
podman build --no-cache -t dotgen .
