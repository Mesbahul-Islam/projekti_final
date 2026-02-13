#!/bin/sh
# Rebalancer - Redistributes services across Docker Swarm nodes
# Only acts when one node is idle (0 services) and another has >1 services

set -u

# ============================================================================
# Configuration
# ============================================================================
STACK_NAME="${STACK_NAME:-hello}"
POLL_SECONDS="${POLL_SECONDS:-15}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-30}"
LOG_FILE="/tmp/rebalance.log"

# ============================================================================
# Logging
# ============================================================================
log() {
  level="$1"
  shift
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  message="[$timestamp] [$level] $*"
  echo "$message"
  echo "$message" >> "$LOG_FILE"
}

log_info()  { log "INFO"  "$@"; }
log_debug() { log "DEBUG" "$@"; }
log_warn()  { log "WARN"  "$@"; }

# ============================================================================
# Utility Functions
# ============================================================================
now_epoch() {
  date +%s
}

is_in_cooldown() {
  svc="$1"
  stamp="/tmp/rebalance_${svc}.stamp"
  now="$(now_epoch)"
  [ ! -f "$stamp" ] && return 1
  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  [ $((now - last)) -lt "$COOLDOWN_SECONDS" ]
}

set_cooldown() {
  svc="$1"
  stamp="/tmp/rebalance_${svc}.stamp"
  now_epoch > "$stamp"
}

# ============================================================================
# Docker Functions
# ============================================================================
get_stack_services() {
  docker service ls --format '{{.Name}}' 2>/dev/null \
    | grep -E "^${STACK_NAME}_" \
    | grep -v -E "^${STACK_NAME}_rebalancer$" \
    | tr '\n' ' ' | sed 's/ $//'
}

get_service_node() {
  docker service ps "$1" --filter "desired-state=running" --format '{{.Node}}' 2>/dev/null | head -1
}

get_swarm_nodes() {
  docker node ls --format '{{.Hostname}}' 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}

force_redistribute_service() {
  svc="$1"
  log_info "Forcing redistribution of $svc"
  docker service update --force "$svc" >/dev/null 2>&1
}

# ============================================================================
# Rebalancing Logic
# ============================================================================
count_services_on_node() {
  services="$1"
  node="$2"
  count=0
  for svc in $services; do
    [ "$(get_service_node "$svc")" = "$node" ] && count=$((count + 1))
  done
  echo "$count"
}

find_idle_and_busy_nodes() {
  services="$1"
  nodes="$2"
  
  idle_node=""
  busy_node=""
  max_count=0
  
  # Build distribution string for logging
  distribution=""
  
  for node in $nodes; do
    count=$(count_services_on_node "$services" "$node")
    distribution="$distribution $node=$count"
    
    # Track idle node (0 services)
    if [ "$count" -eq 0 ]; then
      idle_node="$node"
    fi
    
    # Track busiest node
    if [ "$count" -gt "$max_count" ]; then
      max_count="$count"
      busy_node="$node"
    fi
  done
  
  log_debug "Distribution:$distribution"
  
  # Return result: idle_node busy_node max_count (or empty if no imbalance)
  if [ -n "$idle_node" ] && [ "$max_count" -gt 1 ]; then
    echo "$idle_node $busy_node $max_count"
  fi
}

do_rebalance() {
  services=$(get_stack_services)
  nodes=$(get_swarm_nodes)
  [ -z "$services" ] && return
  [ -z "$nodes" ] && return
  
  log_debug "Services: $services"
  log_debug "Nodes: $nodes"
  
  # Find imbalance
  result=$(find_idle_and_busy_nodes "$services" "$nodes")
  [ -z "$result" ] && return
  
  idle_node=$(echo "$result" | awk '{print $1}')
  busy_node=$(echo "$result" | awk '{print $2}')
  busy_count=$(echo "$result" | awk '{print $3}')
  
  log_info "Imbalance: $busy_node has $busy_count services, $idle_node has 0"
  
  # Force redistribute ONE service not in cooldown
  for svc in $services; do
    [ "$(get_service_node "$svc")" != "$busy_node" ] && continue
    if is_in_cooldown "$svc"; then
      log_debug "$svc in cooldown, skipping"
      continue
    fi
    force_redistribute_service "$svc"
    set_cooldown "$svc"
    return
  done
  
  log_warn "All services in cooldown"
}

# ============================================================================
# Main
# ============================================================================
log_info "Rebalancer started: stack=$STACK_NAME poll=${POLL_SECONDS}s cooldown=${COOLDOWN_SECONDS}s"
log_info "Log file: $LOG_FILE"

while true; do
  do_rebalance
  sleep "$POLL_SECONDS"
done
