#!/usr/bin/env bash
# core/labshell.sh <lab-id> [what-to-set-up] [auto]  - runs inside the lab terminal window.
# Loads the helpers, runs labs/<lab>/run.sh (which defines lab_main), and
# reports the result to the launcher through state/lab<id>.status.
#
# A lab window looks like a terminal in which the commands were typed by hand:
# the normal prompt, the command, its output. Nothing else is printed. When
# the lab is over the window becomes a normal shell in the lab's folder, with
# the lab's environment, and stays open on its own (also when the launcher
# window is closed).

RUNNER_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
LAB_ID="${1:?usage: labshell.sh <lab-id>}"
[ -n "${2:-}" ] && export SETUP_ONLY="$2"
[ "${3:-}" = auto ] && SETUP_AUTO=1

. "$RUNNER_DIR/core/common.sh"
sanitize_env
. "$RUNNER_DIR/core/terminal.sh"
. "$RUNNER_DIR/core/detect.sh"
. "$RUNNER_DIR/core/services.sh"
. "$RUNNER_DIR/core/hadoop.sh"
. "$RUNNER_DIR/core/spark.sh"

# raw lab window: commands, tool output and failures only (config: LAB_RAW_OUTPUT)
RAW_OUTPUT="${LAB_RAW_OUTPUT:-1}"
# Setup and Diagnostics are reports: every line matters, so they are never raw
case "$LAB_ID" in setup|diag) RAW_OUTPUT=0 ;; esac
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

# open_shell : turn the lab window into a normal interactive shell. It reads
# the user's ~/.bashrc like every terminal, then sets the lab's environment
# again (a ~/.bashrc with old exports would otherwise undo it), so commands
# like "hdfs dfs -ls /" can be typed right away.
open_shell() {
  local rc="$STATE_DIR/lab$LAB_ID.bashrc" v
  {
    printf '[ -f %q ] && . %q\n' "$REAL_HOME/.bashrc" "$REAL_HOME/.bashrc"
    for v in JAVA_HOME HADOOP_HOME HADOOP_CONF_DIR HADOOP_LOG_DIR HADOOP_PID_DIR HADOOP_MAPRED_HOME \
             HADOOP_COMMON_HOME HADOOP_HDFS_HOME YARN_HOME HADOOP_CLASSPATH HDFS_NAMENODE_USER \
             HDFS_DATANODE_USER HDFS_SECONDARYNAMENODE_USER PIG_HOME HIVE_HOME HIVE_CONF_DIR \
             SPARK_HOME SPARK_CONF_DIR SPARK_LOCAL_IP PYSPARK_PYTHON PYSPARK_DRIVER_PYTHON \
             KAFKA_HOME LOG_DIR PATH HOME PYTHONUSERBASE; do
      [ -n "${!v:-}" ] && printf 'export %s=%q\n' "$v" "${!v}"
    done
    printf 'cd %q\n' "${LAB_WORK:-$HOME}"
  } > "$rc"
  trap - INT TERM HUP
  exec bash --rcfile "$rc" -i
}

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
  # running in the launcher window, or the window is gone: nothing more to do
  [ -z "${LAB_INLINE:-}" ] && [ -t 0 ] && [ -t 1 ] || return 0
  case "$LAB_ID" in
    setup|diag)
      # a report window. Setup that a lab started by itself closes when it worked.
      if [ "$LAB_ID" = setup ] && [ -n "${SETUP_AUTO:-}" ] && [ "$LAB_RESULT" = OK ]; then sleep 2; return 0; fi
      echo
      # printed with printf: "read -p" writes the prompt to stderr
      printf 'Press ENTER to close this window... '
      read -r _ </dev/tty 2>/dev/null || true ;;
    *)
      open_shell ;;
  esac
}
trap finish EXIT
trap 'LAB_RESULT=FAIL; note_fail "The lab was stopped before it finished (window closed or Ctrl+C)" 2>/dev/null; exit 130' INT TERM HUP

# the prompt this user really has (from ~/.bashrc), so typed-looking lines match it
if [ "$RAW_OUTPUT" = 1 ]; then
  # "detached": an interactive bash started on this terminal would take the
  # terminal over and leave this script stopped in the background
  LAB_PS1=$(detached timeout 10 bash -ic 'printf %s "$PS1"' </dev/null 2>/dev/null)
  # a prompt that needs helper functions of ~/.bashrc cannot be drawn here: use the standard one
  case "$LAB_PS1" in *'$('*|*'`'*) LAB_PS1="" ;; esac
fi
# start like a new terminal: in the home folder, empty screen
cd "$HOME" 2>/dev/null
[ -z "${LAB_INLINE:-}" ] && [ "$RAW_OUTPUT" = 1 ] && [ -t 1 ] && clear
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
