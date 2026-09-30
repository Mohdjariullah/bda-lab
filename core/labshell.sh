#!/usr/bin/env bash
# core/labshell.sh <lab-id>  - runs inside the lab terminal window.
# Loads the helpers, runs labs/<lab>/run.sh (which defines lab_main), and
# reports the result to the launcher through state/lab<id>.status.

RUNNER_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
LAB_ID="${1:?usage: labshell.sh <lab-id>}"

. "$RUNNER_DIR/core/common.sh"
. "$RUNNER_DIR/core/terminal.sh"
. "$RUNNER_DIR/core/sudo.sh"
. "$RUNNER_DIR/core/detect.sh"
. "$RUNNER_DIR/core/services.sh"
. "$RUNNER_DIR/core/hadoop.sh"
. "$RUNNER_DIR/core/spark.sh"

# raw lab window: commands, tool output and failures only (config: LAB_RAW_OUTPUT)
RAW_OUTPUT="${LAB_RAW_OUTPUT:-1}"
export RAW_OUTPUT

LAB_DIR="$(lab_dir_for "$LAB_ID")"
LAB_TITLE="$(lab_title_for "$LAB_ID")"
LAB_NAME="$(lab_short_name "$LAB_ID")"
PROGRESS_FILE="$STATE_DIR/lab$LAB_ID.progress"
STATUS_FILE="$STATE_DIR/lab$LAB_ID.status"
PID_FILE="$STATE_DIR/lab$LAB_ID.pid"
rm -f "$STATUS_FILE"
: > "$PROGRESS_FILE"
echo $$ > "$PID_FILE"

ts=$(date +%Y%m%d_%H%M%S)
LAB_LOG="$LOG_DIR/lab${LAB_ID}_$ts.log"
: > "$LAB_LOG"
ln -sfn "$LAB_LOG" "$LOG_DIR/lab$LAB_ID.log"
export LAB_ID LAB_DIR LAB_LOG PROGRESS_FILE STATUS_FILE

LAB_RESULT=""
finish() {
  local rc=$?
  trap - EXIT
  if [ -z "$LAB_RESULT" ]; then
    [ "$rc" -eq 0 ] && LAB_RESULT=OK || LAB_RESULT=FAIL
  fi
  cleanup_background
  if [ "$LAB_RESULT" = OK ]; then
    banner "$(echo "$LAB_TITLE" | tr 'a-z' 'A-Z') - COMPLETED SUCCESSFULLY"
    note_ok "$LAB_NAME done"
  else
    banner "$(echo "$LAB_TITLE" | tr 'a-z' 'A-Z') - FAILED"
    note_fail "$LAB_NAME failed. Log: $LAB_LOG"
  fi
  _logline "Finished: $(date)"
  _logline "Full log: $LAB_LOG"
  [ "$RAW_OUTPUT" = 1 ] || { echo "Finished: $(date)"; echo "Full log: $LAB_LOG"; }
  write_status "$LAB_RESULT"
  rm -f "$PID_FILE"
  if [ -z "${LAB_INLINE:-}" ] && [ -r /dev/tty ]; then
    # raw mode: no text, but the window still waits so the output can be read
    if [ "$RAW_OUTPUT" = 1 ]; then
      read -r _ </dev/tty 2>/dev/null || true
    else
      echo
      read -rp "Press ENTER to close this window..." _ </dev/tty 2>/dev/null || true
    fi
  fi
}
trap finish EXIT
trap 'LAB_RESULT=FAIL; exit 130' INT TERM HUP

banner "$(echo "$LAB_TITLE" | tr 'a-z' 'A-Z')"
if [ "$RAW_OUTPUT" != 1 ]; then
  echo "Started : $(date)"
  echo "User    : $(id -un)@$(hostname)"
  echo "Log     : $LAB_LOG"
fi
{ echo "# $LAB_TITLE"; echo "# started $(date) by $(id -un)@$(hostname)"; } >> "$LAB_LOG"

[ -f "$LAB_DIR/run.sh" ] || die "Missing $LAB_DIR/run.sh"
. "$LAB_DIR/run.sh"
type lab_main >/dev/null 2>&1 || die "$LAB_DIR/run.sh does not define lab_main"

if lab_main; then
  LAB_RESULT=OK
  exit 0
else
  LAB_RESULT=FAIL
  exit 1
fi
