#!/bin/bash
set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="${NAMESPACE:-default}"

echo "Stopping all tasks..."
"$KUBECTL_BIN" -n "$NAMESPACE" delete -f hello-k3s.yml

echo "Tasks stopped."