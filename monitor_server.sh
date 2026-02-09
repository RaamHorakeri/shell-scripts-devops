#!/bin/bash

# ==============================
# CONFIGURATION
# ==============================
WEBHOOK_URL="$SYSTEM_METRICS"
STATE_FILE="/tmp/server_alert_state.txt"
SERVER_NAME="$(curl -s http://169.254.169.254/metadata/v1/hostname || hostname)"

# Ensure state file exists
touch "$STATE_FILE"

echo "📊 Fetching metrics for server: $SERVER_NAME"

# ==============================
# COLLECT METRICS (LOCAL ONLY)
# ==============================

# CPU Usage (user + system)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')

# Memory Usage
MEM_USED=$(free -m | awk 'NR==2{print $3}')
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_PERCENT=$(( MEM_USED * 100 / MEM_TOTAL ))

# Disk Usage (root partition)
DISK_USED=$(df -h / | awk 'NR==2{print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
DISK_PERCENT=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

# ==============================
# DETERMINE HIGHEST USAGE
# ==============================
HIGHEST_USAGE=$CPU_USAGE
[ "$MEM_PERCENT" -gt "$HIGHEST_USAGE" ] && HIGHEST_USAGE=$MEM_PERCENT
[ "$DISK_PERCENT" -gt "$HIGHEST_USAGE" ] && HIGHEST_USAGE=$DISK_PERCENT

# ==============================
# LOAD PREVIOUS ALERT STATE
# ==============================
LAST_STATE=$(awk -F':' '{print $1}' "$STATE_FILE")
LAST_ALERT_TIME=$(awk -F':' '{print $2}' "$STATE_FILE")
LAST_STATE=${LAST_STATE:-0}
LAST_ALERT_TIME=${LAST_ALERT_TIME:-0}

# ==============================
# DETERMINE ALERT LEVEL
# ==============================
ALERT_LEVEL=0

if [ "$HIGHEST_USAGE" -ge 90 ]; then
    ALERT_LEVEL=3
elif [ "$HIGHEST_USAGE" -ge 70 ]; then
    ALERT_LEVEL=2
elif [ "$HIGHEST_USAGE" -ge 50 ]; then
    ALERT_LEVEL=1
fi

# ==============================
# NORMAL STATE (RESET ALERT)
# ==============================
if [ "$ALERT_LEVEL" -eq 0 ]; then
    echo "✅ Server usage normal (${HIGHEST_USAGE}%)"
    > "$STATE_FILE"
    exit 0
fi

# ==============================
# ALERT LOGIC (ANTI-SPAM)
# ==============================
SEND_ALERT=false
NOW=$(date +%s)

if [ "$ALERT_LEVEL" -gt "$LAST_STATE" ]; then
    SEND_ALERT=true
elif [ "$ALERT_LEVEL" -eq 3 ]; then
    # Repeat critical alerts every 10 mins
    if [ $((NOW - LAST_ALERT_TIME)) -ge 600 ]; then
        SEND_ALERT=true
    fi
fi

# ==============================
# SEND ALERT
# ==============================
if $SEND_ALERT; then
    MESSAGE="**Server:** $SERVER_NAME<br>**CPU:** ${CPU_USAGE}%<br>**Memory:** ${MEM_USED}/${MEM_TOTAL} MB (${MEM_PERCENT}%)<br>**Disk:** ${DISK_USED}/${DISK_TOTAL} (${DISK_PERCENT}%)"

    echo -e "🚨 Server Resource Alert 🚨"
    echo "CPU: ${CPU_USAGE}%"
    echo "Memory: ${MEM_USED}/${MEM_TOTAL} MB (${MEM_PERCENT}%)"
    echo "Disk: ${DISK_USED}/${DISK_TOTAL} (${DISK_PERCENT}%)"

    curl -s -H "Content-Type: application/json" -d "{
        \"@type\": \"MessageCard\",
        \"@context\": \"https://schema.org/extensions\",
        \"summary\": \"Server Resource Alert\",
        \"themeColor\": \"FF0000\",
        \"title\": \"🚨 Server Resource Alert (Level $ALERT_LEVEL) 🚨\",
        \"text\": \"$MESSAGE\"
    }" "$WEBHOOK_URL" > /dev/null

    echo "$ALERT_LEVEL:$NOW" > "$STATE_FILE"
else
    echo "ℹ️ Alert already sent for this level (Level: $ALERT_LEVEL)"
fi
