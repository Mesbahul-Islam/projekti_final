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

  # Get nodes
  node1=$(docker node ls --format '{{.Hostname}}' | head -1)
  node2=$(docker node ls --format '{{.Hostname}}' | tail -1)

  # Count services per node
  count1=0
  count2=0
  for svc in $services; do
    node=$(get_service_node "$svc")
    if [ "$node" = "$node1" ]; then
      count1=$((count1 + 1))
    elif [ "$node" = "$node2" ]; then
      count2=$((count2 + 1))
    fi
  done

  echo "[debug] $node1: $count1, $node2: $count2"

  # Check for imbalance
  if [ $count1 -eq 0 ] && [ $count2 -gt 1 ]; then
    idle_node=$node1
    busy_node=$node2
    busy_count=$count2
  elif [ $count2 -eq 0 ] && [ $count1 -gt 1 ]; then
    idle_node=$node2
    busy_node=$node1
    busy_count=$count1
  else
    idle_node=""
  fi

  if [ -n "$idle_node" ]; then
    # Find a service on busy_node to move
    for svc in $services; do
      if [ "$(get_service_node "$svc")" = "$busy_node" ]; then
        if should_update "$svc"; then
          echo "[rebalancer] imbalance: $busy_node has $busy_count, $idle_node has 0 -> moving $svc to $idle_node"
          docker service update --constraint "node.hostname == $idle_node" "$svc" >/dev/null 2>&1 || true
        else
          echo "[rebalancer] imbalance detected but $svc in cooldown"
        fi
        break
      fi
    done
  fi

  sleep "$POLL_SECONDS"
done
