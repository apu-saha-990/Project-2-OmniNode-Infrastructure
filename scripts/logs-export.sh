#!/bin/bash
# =============================================================
# OmniNode Log Exporter — scripts/logs-export.sh
# Exports all container logs to project logs/ directory
# Run manually: ./omninode logs-export
# Auto-runs on: ./omninode stop all
# =============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$ROOT_DIR/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
EXPORT_DIR="$LOGS_DIR/$TIMESTAMP"

# Load env
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Containers to export
CONTAINERS=(
    "omninode-bitcoin"
    "omninode-ethereum"
    "omninode-lighthouse"
    "omninode-prometheus"
    "omninode-grafana"
    "omninode-alertmanager"
    "omninode-bitcoin-exporter"
    "omninode-discord-proxy"
)

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       OmniNode Log Exporter                      ║${NC}"
echo -e "${BOLD}${CYAN}║       Capturing container logs to disk           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Export path:${NC} $EXPORT_DIR"
echo -e "  ${BLUE}Timestamp:${NC}   $TIMESTAMP"
echo ""

# Create export directory
mkdir -p "$EXPORT_DIR"

# Export logs for each container
SUCCESS=0
FAILED=0

for CONTAINER in "${CONTAINERS[@]}"; do
    # Strip omninode- prefix for filename
    NAME="${CONTAINER#omninode-}"
    LOG_FILE="$EXPORT_DIR/${NAME}.log"

    # Check if container exists (running or stopped)
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        docker logs "$CONTAINER" > "$LOG_FILE" 2>&1
        LINE_COUNT=$(wc -l < "$LOG_FILE")
        echo -e "  ${GREEN}✓${NC} ${NAME}.log — ${LINE_COUNT} lines"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} $CONTAINER — not found, skipping"
        FAILED=$((FAILED + 1))
    fi
done

echo ""

# Write export metadata
META_FILE="$EXPORT_DIR/export-info.txt"
cat > "$META_FILE" << EOF
OmniNode Log Export
===================
Timestamp:     $TIMESTAMP
Export path:   $EXPORT_DIR
Containers:    $SUCCESS exported, $FAILED skipped

Containers exported:
$(for c in "${CONTAINERS[@]}"; do echo "  - $c"; done)

How to read logs:
  cat $EXPORT_DIR/bitcoin.log
  grep "ERROR" $EXPORT_DIR/ethereum.log
  grep "WARN" $EXPORT_DIR/lighthouse.log
EOF

echo -e "  ${GREEN}✓${NC} export-info.txt — metadata written"
echo ""

# Retention — keep last 10 exports
EXPORT_COUNT=$(ls -d "$LOGS_DIR"/*/  2>/dev/null | wc -l)
if [ "$EXPORT_COUNT" -gt 10 ]; then
    OLDEST=$(ls -dt "$LOGS_DIR"/*/ | tail -1)
    rm -rf "$OLDEST"
    echo -e "  ${YELLOW}→${NC} Removed oldest export to maintain 10-export retention"
    echo ""
fi

# Summary
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}✓ Log export complete — $SUCCESS containers captured${NC}"
echo -e "  ${BLUE}Location:${NC} $EXPORT_DIR"
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
echo ""
