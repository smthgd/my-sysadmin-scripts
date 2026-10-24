readonly N=5
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="$SCRIPT_DIR/monitor.log"

while true; do
    {
        printf '%s\n' "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        printf '\n'
    } >> "$LOG_FILE"

    sleep "$N"
done
