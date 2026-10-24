#!/usr/bin/env bash

readonly N=5
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="$SCRIPT_DIR/monitor.log"

for command in free df uptime date sleep; do
    if ! command -v "$command" > /dev/null; then
        echo "Ошибка: команда $command не найдена." >&2
        exit 1
    fi
done

if ! touch "$LOG_FILE"; then
    echo "Ошибка: не удалось создать или открыть журнал $LOG_FILE." >&2
    exit 1
fi

while true; do
    if ! {
        printf '%s\n' "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        printf '\n'
    } >> "$LOG_FILE"; then
        echo "Ошибка записи в журнал $LOG_FILE." >&2
        exit 1
    fi

    sleep "$N"
done
