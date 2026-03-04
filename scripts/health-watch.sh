#!/bin/bash
# =============================================================
# OmniNode Health Watchdog — scripts/health-watch.sh
# Independent monitoring — bypasses Prometheus entirely
# Talks directly to Discord via webhook
# Run manually: ./omninode health-watch
# Run as cron: */5 * * * * /path/to/health-watch.sh
# =============================================================

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# =============================================================
# Configuration
# =============================================================
DISCORD_URL="${DISCORD_WEBHOOK_URL}"
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Containers to check
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

# =============================================================
# Colours for terminal output
# =============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================
# Discord notification function
# =============================================================
send_discord() {
    local message="$1"
    if [ -z "$DISCORD_URL" ] || [ "$DISCORD_URL" = "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE" ]; then
        echo -e "${YELLOW}  ⚠ Discord webhook not configured — skipping notification${NC}"
        return
    fi
    curl -s -X POST "$DISCORD_URL" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}" > /dev/null 2>&1
}

# =============================================================
# Check functions
# =============================================================

check_containers() {
    local failed=0
    local failed_list=""

    echo -e "${BLUE}  Checking containers...${NC}"

    for container in "${CONTAINERS[@]}"; do
        status=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null)
        if [ "$status" = "true" ]; then
            echo -e "  ${GREEN}✓${NC} $container"
        else
            echo -e "  ${RED}✗${NC} $container — NOT RUNNING"
            failed=$((failed + 1))
            failed_list="$failed_list\n• $container"
        fi
    done

    if [ $failed -gt 0 ]; then
        send_discord "🔴 **OmniNode Health Watchdog**\n\n**$failed container(s) down:**$failed_list\n\nTime: $TIMESTAMP"
        return 1
    fi
    return 0
}

check_bitcoin() {
    echo -e "${BLUE}  Checking Bitcoin RPC...${NC}"
    result=$(docker exec omninode-bitcoin bitcoin-cli \
        -rpcuser="${BTC_RPC_USER}" \
        -rpcpassword="${BTC_RPC_PASS}" \
        getblockchaininfo 2>/dev/null | grep -c "blocks")

    if [ "$result" -gt 0 ]; then
        blocks=$(docker exec omninode-bitcoin bitcoin-cli \
            -rpcuser="${BTC_RPC_USER}" \
            -rpcpassword="${BTC_RPC_PASS}" \
                getblockcount 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} Bitcoin RPC responding — block height: $blocks"
        return 0
    else
        echo -e "  ${RED}✗${NC} Bitcoin RPC not responding"
        send_discord "🔴 **OmniNode Health Watchdog**\n\n**Bitcoin RPC not responding**\nNode may be down or syncing.\n\nTime: $TIMESTAMP"
        return 1
    fi
}

check_ethereum() {
    echo -e "${BLUE}  Checking Ethereum RPC...${NC}"
    result=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' 2>/dev/null)

    if [ "$result" = "200" ]; then
        peers=$(curl -s -X POST http://localhost:8545 \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | \
            python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))" 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} Ethereum RPC responding — peers: $peers"
        return 0
    else
        echo -e "  ${RED}✗${NC} Ethereum RPC not responding"
        send_discord "🔴 **OmniNode Health Watchdog**\n\n**Ethereum RPC not responding**\nNode may be down or syncing.\n\nTime: $TIMESTAMP"
        return 1
    fi
}

check_lighthouse() {
    echo -e "${BLUE}  Checking Lighthouse beacon...${NC}"
    result=$(curl -s -o /dev/null -w "%{http_code}" \
        http://localhost:5052/eth/v1/node/health 2>/dev/null)

    if [ "$result" = "200" ] || [ "$result" = "206" ]; then
        echo -e "  ${GREEN}✓${NC} Lighthouse beacon responding"
        return 0
    else
        echo -e "  ${RED}✗${NC} Lighthouse beacon not responding"
        send_discord "🔴 **OmniNode Health Watchdog**\n\n**Lighthouse beacon not responding**\nBeacon client may be down.\n\nTime: $TIMESTAMP"
        return 1
    fi
}

check_disk() {
    echo -e "${BLUE}  Checking disk space...${NC}"
    DISK_USAGE=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | tr -d '%')
    DISK_FREE=$(df -h "$PROJECT_DIR" | tail -1 | awk '{print $4}')

    if [ "$DISK_USAGE" -ge "$DISK_CRITICAL_THRESHOLD" ]; then
        echo -e "  ${RED}✗${NC} Disk usage CRITICAL: ${DISK_USAGE}% used — ${DISK_FREE} free"
        send_discord "🔴 **OmniNode Health Watchdog**\n\n**Disk space CRITICAL: ${DISK_USAGE}% used**\nOnly ${DISK_FREE} remaining. Nodes may crash.\n\nTime: $TIMESTAMP"
        return 1
    elif [ "$DISK_USAGE" -ge "$DISK_WARNING_THRESHOLD" ]; then
        echo -e "  ${YELLOW}⚠${NC} Disk usage WARNING: ${DISK_USAGE}% used — ${DISK_FREE} free"
        send_discord "🟡 **OmniNode Health Watchdog**\n\n**Disk space WARNING: ${DISK_USAGE}% used**\n${DISK_FREE} remaining. Monitor closely.\n\nTime: $TIMESTAMP"
        return 1
    else
        echo -e "  ${GREEN}✓${NC} Disk space OK: ${DISK_USAGE}% used — ${DISK_FREE} free"
        return 0
    fi
}

# =============================================================
# Main
# =============================================================
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       OmniNode Health Watchdog                   ║${NC}"
echo -e "${BLUE}║       Independent System Check                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo -e "  ${BLUE}Time:${NC} $TIMESTAMP"
echo ""

ISSUES=0

check_containers  || ISSUES=$((ISSUES + 1))
echo ""
check_bitcoin     || ISSUES=$((ISSUES + 1))
echo ""
check_ethereum    || ISSUES=$((ISSUES + 1))
echo ""
check_lighthouse  || ISSUES=$((ISSUES + 1))
echo ""
check_disk        || ISSUES=$((ISSUES + 1))
echo ""

# =============================================================
# Summary
# =============================================================
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "  ${GREEN}✓ All checks passed — OmniNode is healthy${NC}"
    echo ""
else
    echo -e "  ${RED}✗ $ISSUES issue(s) detected — check Discord for alerts${NC}"
    echo ""
fi
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
echo ""

exit $ISSUES
