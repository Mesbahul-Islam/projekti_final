#!/bin/bash
set -euo pipefail

IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILD_MODE="${BUILD_MODE:-native}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}"

build_task() {
	local task_num="$1"
	local context_dir="$2"
	local image_ref="${IMAGE_REGISTRY}/task${task_num}:${IMAGE_TAG}"

	if [[ "$BUILD_MODE" == "multiarch" ]]; then
		docker buildx build \
			--platform "$PLATFORMS" \
			-t "$image_ref" \
			--push \
			"$context_dir"
	elif [[ "$BUILD_MODE" == "native" ]]; then
		docker build \
			-t "$image_ref" \
			"$context_dir"
	else
		echo "Error: BUILD_MODE must be 'native' or 'multiarch'"
		exit 1
	fi
}

echo "Building images..."
echo "IMAGE_REGISTRY=$IMAGE_REGISTRY"
echo "IMAGE_TAG=$IMAGE_TAG"
echo "BUILD_MODE=$BUILD_MODE"
echo "PLATFORMS=$PLATFORMS"

if [[ "$BUILD_MODE" == "multiarch" && "$IMAGE_REGISTRY" == "local" ]]; then
	echo "Error: BUILD_MODE=multiarch requires IMAGE_REGISTRY to be a real registry (not 'local')."
	echo "Example: IMAGE_REGISTRY=docker.io/<username> BUILD_MODE=multiarch ./build.sh"
	exit 1
fi

build_task 1 hello_tx/
build_task 2 hello_rx/
build_task 3 hello_tx2/
build_task 4 hello_rx2/

echo "Build complete."