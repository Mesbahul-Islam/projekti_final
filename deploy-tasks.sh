#!/bin/bash
set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NAMESPACE="${NAMESPACE:-default}"

echo "Deploying app stack..."
"$KUBECTL_BIN" -n "$NAMESPACE" apply -f hello-k3s.yml

echo "Updating deployment images..."
"$KUBECTL_BIN" -n "$NAMESPACE" set image deployment/hello-task1 task1="${IMAGE_REGISTRY}/task1:${IMAGE_TAG}"
"$KUBECTL_BIN" -n "$NAMESPACE" set image deployment/hello-task2 task2="${IMAGE_REGISTRY}/task2:${IMAGE_TAG}"
"$KUBECTL_BIN" -n "$NAMESPACE" set image deployment/hello-task3 task3="${IMAGE_REGISTRY}/task3:${IMAGE_TAG}"
"$KUBECTL_BIN" -n "$NAMESPACE" set image deployment/hello-task4 task4="${IMAGE_REGISTRY}/task4:${IMAGE_TAG}"

echo "App deploy complete."
echo "Namespace: ${NAMESPACE}"
echo "Using images: ${IMAGE_REGISTRY}/task{1..4}:${IMAGE_TAG}"