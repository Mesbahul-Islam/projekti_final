#!/bin/sh

set -u

STACK_NAME="${STACK_NAME:-hello}"
POLL_SECONDS="${POLL_SECONDS:-15}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-60}"

now_epoch() {
  date +%s
}

should_update() {
  svc="$1"
  stamp="/tmp/rebalance_${svc}.stamp"
  now="$(now_epoch)"

  if [ ! -f "$stamp" ]; then
    echo "$now" > "$stamp"
    echo "[debug] updating $svc (first time)"
    return 0
  fi

  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [ $((now - last)) -ge "$COOLDOWN_SECONDS" ]; then
    echo "$now" > "$stamp"
    echo "[debug] updating $svc (cooldown expired)"
    return 0
  fi

  echo "[debug] $svc in cooldown"
  return 1
}

list_stack_services() {
  docker service ls --format '{{.Name}}' \
    | grep -E "^${STACK_NAME}_" \
    | grep -v -E "^${STACK_NAME}_rebalancer$" || true
}

get_service_node() {
  svc="$1"
  docker service ps "$svc" --format '{{.Node}}' | head -1
}

echo "[rebalancer] stack=$STACK_NAME poll=${POLL_SECONDS}s cooldown=${COOLDOWN_SECONDS}s"

while true; do
  services="$(list_stack_services)"
  echo "[debug] checking services: $services"

  # Compute node counts
  unset node_counts
  declare -A node_counts
  for svc in $services; do
    node=$(get_service_node "$svc")
    if [ -n "$node" ]; then
      node_counts[$node]=$(( ${node_counts[$node]:-0} + 1 ))
    fi
  done

  # Find min and max counts
  min_count=999
  max_count=0
  idle_node=""
  busy_node=""
  for node in "${!node_counts[@]}"; do
    count=${node_counts[$node]}
    if [ $count -lt $min_count ]; then
      min_count=$count
      idle_node=$node
    fi
    if [ $count -gt $max_count ]; then
      max_count=$count
      busy_node=$node
    fi
  done

  if [ $min_count -eq 0 ] && [ $max_count -gt 1 ]; then
    # Find a service on busy_node to move
    for svc in $services; do
      if [ "$(get_service_node "$svc")" = "$busy_node" ]; then
        if should_update "$svc"; then
          echo "[rebalancer] imbalance: $busy_node has $max_count, $idle_node has $min_count -> moving $svc to $idle_node"
          docker service update --constraint "node.hostname == $idle_node" "$svc" >/dev/null 2>&1 || true
        else
          echo "[rebalancer] imbalance detected but $svc in cooldown"
        fi
        break
      fi
    done
  else
    echo "[debug] balance ok: min=$min_count max=$max_count"
  fi

  sleep "$POLL_SECONDS"
done
