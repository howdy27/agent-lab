#!/bin/bash

# 로그 파일 경로
LOG_FILE=/var/log/agent-app/monitor.log

# 현재 시간
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# =====================
# Health Check
# =====================

# 프로세스 확인
if ! pgrep -f "agent-app-linux-arm64" > /dev/null; then
    echo "[$TIMESTAMP] [ERROR] agent-app process not running" >> $LOG_FILE
    exit 1
fi

# 포트 확인
if ! ss -tulnp | grep ":15034" > /dev/null; then
    echo "[$TIMESTAMP] [ERROR] Port 15034 not listening" >> $LOG_FILE
    exit 1
fi

# =====================
# 방화벽 상태 점검
# =====================
UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -z "$UFW_STATUS" ]; then
    echo "[$TIMESTAMP] [WARNING] UFW is not active" >> $LOG_FILE
fi

# =====================
# 자원 수집
# =====================

# CPU 사용률
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# 메모리 사용률
MEM=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')

# 디스크 사용률
DISK=$(df / | grep / | awk '{print $5}' | cut -d'%' -f1)

# =====================
# 임계값 경고
# =====================
if [ $(echo "$CPU > 20" | bc) -eq 1 ]; then
    echo "[$TIMESTAMP] [WARNING] CPU usage high: ${CPU}%" >> $LOG_FILE
fi

if [ $(echo "$MEM > 10" | bc) -eq 1 ]; then
    echo "[$TIMESTAMP] [WARNING] MEM usage high: ${MEM}%" >> $LOG_FILE
fi

if [ "$DISK" -gt 80 ]; then
    echo "[$TIMESTAMP] [WARNING] DISK usage high: ${DISK}%" >> $LOG_FILE
fi

# =====================
# 로그 기록

PID=$(pgrep -f agent-app-linux-arm64 | tr '\n' ' ')
echo "[$TIMESTAMP] PID:${PID}CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK}%" >> $LOG_FILE

# =====================
# 로그 용량 관리
# =====================
MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_SIZE ]; then
    for i in 9 8 7 6 5 4 3 2 1; do
        if [ -f "${LOG_FILE}.$i" ]; then
            mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        fi
    done
    mv "$LOG_FILE" "${LOG_FILE}.1"
fi