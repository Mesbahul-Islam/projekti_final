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

service_has_failures() {
  svc="$1"

  # Look for scheduler/task failures
  docker service ps "$svc" --no-trunc --format '{{.CurrentState}}|{{.Error}}' 2>/dev/null \
    | grep -Ei 'Rejected|Failed|No such image|error' >/dev/null 2>&1
}

echo "[rebalancer] stack=$STACK_NAME poll=${POLL_SECONDS}s cooldown=${COOLDOWN_SECONDS}s"

while true; do
  services="$(list_stack_services)"
  echo "[debug] checking services: $services"

  for svc in $services; do
    if service_has_failures "$svc"; then
      echo "[debug] failures detected in $svc"
      if should_update "$svc"; then
        echo "[rebalancer] failures detected in $svc -> docker service update --force"
        docker service update --force "$svc" >/dev/null 2>&1 || true
      else
        echo "[rebalancer] failures detected in $svc but in cooldown"
      fi
    else
      echo "[debug] no failures in $svc"
    fi
  done

  sleep "$POLL_SECONDS"
done
