#!/bin/bash

# =============================================================
# OmniNode — Port Availability Checker
# Checks all required ports before node startup
# =============================================================

set -euo pipefail

# Load env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
  echo "❌ .env file not found. Copy .env.example to .env first."
  exit 1
fi

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Port map — name:port
declare -A PORTS=(
  ["Bitcoin RPC"]="$BTC_RPC_PORT"
  ["Bitcoin P2P"]="$BTC_P2P_PORT"
  ["Ethereum HTTP RPC"]="$ETH_HTTP_PORT"
  ["Ethereum WebSocket"]="$ETH_WS_PORT"
  ["Ethereum P2P"]="$ETH_P2P_PORT"
  ["Ethereum Metrics"]="$ETH_METRICS_PORT"
  ["Prometheus"]="$PROMETHEUS_PORT"
  ["Grafana"]="$GRAFANA_PORT"
  ["Alertmanager"]="$ALERTMANAGER_PORT"
)

CONFLICTS=0
ALL_CLEAR=0

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     OmniNode — Port Availability Check   ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

for SERVICE in "${!PORTS[@]}"; do
  PORT="${PORTS[$SERVICE]}"
  if lsof -iTCP:"$PORT" -sTCP:LISTEN -n -P &>/dev/null 2>&1; then
    echo -e "  ${RED}✗ CONFLICT${NC}  Port ${BOLD}$PORT${NC} — $SERVICE — already in use"
    CONFLICTS=$((CONFLICTS + 1))
  else
    echo -e "  ${GREEN}✓ FREE${NC}     Port ${BOLD}$PORT${NC} — $SERVICE"
    ALL_CLEAR=$((ALL_CLEAR + 1))
  fi
done

echo ""
echo -e "${BOLD}──────────────────────────────────────────────${NC}"

if [ $CONFLICTS -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All ports available. Safe to start OmniNode.${NC}"
  echo ""
  exit 0
else
  echo -e "  ${RED}${BOLD}$CONFLICTS port conflict(s) detected.${NC}"
  echo -e "  ${YELLOW}Update the conflicting ports in your .env file before starting.${NC}"
  echo ""
  exit 1
fi
