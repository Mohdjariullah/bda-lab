#!/usr/bin/env bash
# core/common.sh - shared helpers. Sourced by lab-runner, labshell.sh, askpass.sh, diagnostics.sh
# Nothing in this file prints on its own; it only defines functions and variables.

[ -n "${__COMMON_LOADED:-}" ] && return 0
__COMMON_LOADED=1

if [ -z "${RUNNER_DIR:-}" ]; then
  RUNNER_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
fi
export RUNNER_DIR
CORE_DIR="$RUNNER_DIR/core"
LABS_DIR="$RUNNER_DIR/labs"
CONFIG_DIR="$RUNNER_DIR/config"
STATE_DIR="$RUNNER_DIR/state"
LOG_DIR="$RUNNER_DIR/logs"
RESULTS_DIR="$RUNNER_DIR/results"
mkdir -p "$STATE_DIR" "$LOG_DIR" "$RESULTS_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true

# ---- configuration ---------------------------------------------------------
# detected.env holds DETECTED_* variables written by the runner after a search.
# environment.conf holds the user's CFG_* overrides. Config always wins.
[ -f "$STATE_DIR/detected.env" ] && . "$STATE_DIR/detected.env"
[ -f "$CONFIG_DIR/environment.conf" ] && . "$CONFIG_DIR/environment.conf"

: "${LAB_WORKDIR_BASE:=$HOME/bigdata_labs}"
: "${HDFS_LAB_BASE:=/user/$(id -un)/bigdata_labs}"
: "${SEARCH_ROOTS:=$HOME /home /opt /usr/local /usr/lib /usr/share}"
: "${HADOOP_DATA_DIR:=$HOME/hadoopdata}"
: "${AUTO_WRITE_HADOOP_CONF:=1}"
: "${AUTO_INSTALL_PY:=1}"
: "${AUTO_START_SERVICES:=1}"
: "${SERVICE_TIMEOUT:=90}"
: "${MAX_FIX_ATTEMPTS:=2}"
: "${LAB9_STREAM_PORT:=9999}"
: "${KAFKA_PORT:=9092}"
: "${AUTO_SETUP:=1}"
: "${STACK_DIR:=$HOME/bigdata_stack}"

# ---- lab table -------------------------------------------------------------
LAB_IDS=(01 02 03 04a 04b 05 06 07 08 09 10)
lab_title_for() {
  case "$1" in
    01)  echo "Lab 1  - Installation and Verification" ;;
    02)  echo "Lab 2  - Data Visualization in Python" ;;
    03)  echo "Lab 3  - Basic HDFS Commands" ;;
    04a) echo "Lab 4a - MapReduce Word Count" ;;
    04b) echo "Lab 4b - MapReduce Weather (Max Temperature)" ;;
    05)  echo "Lab 5  - Apache Pig Java UDF" ;;
    06)  echo "Lab 6  - MongoDB NoSQL Operations" ;;
    07)  echo "Lab 7  - Hive HiveQL + Java UDF" ;;
    08)  echo "Lab 8  - Apache Spark Processing" ;;
    09)  echo "Lab 9  - Spark Structured Streaming" ;;
    10)  echo "Lab 10 - Kafka Event Streaming" ;;
    diag) echo "System Diagnostics" ;;
    setup) echo "Setup - Install All Lab Software" ;;
    *)   echo "Lab $1" ;;
  esac
}
lab_dir_for() {
  case "$1" in
    04a) echo "$LABS_DIR/lab04/wordcount" ;;
    04b) echo "$LABS_DIR/lab04/weather" ;;
    diag) echo "$CORE_DIR/diag" ;;
    setup) echo "$CORE_DIR/setup" ;;
    *)   echo "$LABS_DIR/lab$1" ;;
  esac
}
lab_short_name() {   # "Lab 5" from "05", "Lab 4a" from "04a"
  lab_title_for "$1" | sed -E 's/ +- .*//'
}

# ---- colours ---------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
  C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi
LINE="============================================================"
LINE2="------------------------------------------------------------"

# ---- printing --------------------------------------------------------------
# every status line is also written to the lab log, so the log alone tells the story
hr()      { echo "$LINE"; }
banner()  { echo; echo "$LINE"; printf ' %s\n' "$@"; echo "$LINE"; _logline ""; _logline "$LINE"; _logline " $*"; _logline "$LINE"; }
ok()      { echo "${C_GREEN}[✓]${C_RESET} $*";   _logline "[OK] $*"; }
fail()    { echo "${C_RED}[✗]${C_RESET} $*";     _logline "[FAIL] $*"; }
warn()    { echo "${C_YELLOW}[!]${C_RESET} $*";  _logline "[WARN] $*"; }
info()    { echo "${C_BLUE}[→]${C_RESET} $*";    _logline "[INFO] $*"; }
fixmsg()  { echo "${C_CYAN}[FIX]${C_RESET} $*";  _logline "[FIX] $*"; }
check()   { echo; echo "${C_BOLD}[CHECK]${C_RESET} $*"; _logline ""; _logline "[CHECK] $*"; }
step()    { echo; echo "${C_BOLD}[STEP $1] $2${C_RESET}"; _logline ""; _logline "[STEP $1] $2"; }
show()    { printf '\n%s$ %s%s\n' "$C_BOLD" "$*" "$C_RESET"; _logline ""; _logline "$ $*"; }

# progress lines are read by the launcher window
progress()  { [ -n "${PROGRESS_FILE:-}" ] && printf '%s\n' "$*" >> "$PROGRESS_FILE"; return 0; }
note_ok()   { ok "$@";     progress "[✓] $*"; }
note_fail() { fail "$@";   progress "[✗] $*"; }
note_warn() { warn "$@";   progress "[!] $*"; }
note_info() { info "$@";   progress "[→] $*"; }
note_fix()  { fixmsg "$@"; progress "[FIX] $*"; }

_logline() { [ -n "${LAB_LOG:-}" ] && printf '%s\n' "$*" >> "$LAB_LOG"; return 0; }

# ---- running commands ------------------------------------------------------
# run CMD ARGS...   : echo the command, run it, show output, log it, return its exit code
run() {
  printf '\n%s$ %s%s\n' "$C_BOLD" "$*" "$C_RESET"
  _logline "" ; _logline "$ $*"
  "$@" 2>&1 | tee -a "${LAB_LOG:-/dev/null}"
  return "${PIPESTATUS[0]}"
}
# run_as "label shown" CMD ARGS... : same as run, but displays a shorter label
run_as() {
  local label=$1; shift
  printf '\n%s$ %s%s\n' "$C_BOLD" "$label" "$C_RESET"
  _logline "" ; _logline "$ $label"
  "$@" 2>&1 | tee -a "${LAB_LOG:-/dev/null}"
  return "${PIPESTATUS[0]}"
}
# run_sh "shell string" : for pipes and redirections
run_sh() {
  printf '\n%s$ %s%s\n' "$C_BOLD" "$1" "$C_RESET"
  _logline "" ; _logline "$ $1"
  bash -c "$1" 2>&1 | tee -a "${LAB_LOG:-/dev/null}"
  return "${PIPESTATUS[0]}"
}
# run_t SECONDS CMD... : run with a hard timeout (prevents hangs)
run_t() { local t=$1; shift; run timeout --foreground -k 5 "$t" "$@"; }
# run_pipe FILTERFN CMD... : like run, but the output passes through the shell
# function FILTERFN before it is shown and logged. Exit code is the command's.
run_pipe() {
  local filt=$1; shift
  printf '\n%s$ %s%s\n' "$C_BOLD" "$*" "$C_RESET"
  _logline "" ; _logline "$ $*"
  "$@" 2>&1 | "$filt" | tee -a "${LAB_LOG:-/dev/null}"
  return "${PIPESTATUS[0]}"
}
# quiet: log only, nothing on screen
run_quiet() { "$@" >> "${LAB_LOG:-/dev/null}" 2>&1; }

# run_fix FIXFN CMD... : run CMD; if it fails call FIXFN (gets the exit code),
# and if FIXFN returns 0 run CMD again. Never loops more than MAX_FIX_ATTEMPTS.
run_fix() {
  local fixfn=$1; shift
  local n=0 rc
  while :; do
    run "$@"; rc=$?
    [ "$rc" -eq 0 ] && return 0
    n=$((n + 1))
    [ "$n" -gt "$MAX_FIX_ATTEMPTS" ] && return "$rc"
    warn "Command failed (exit $rc). Trying automatic fix ($n/$MAX_FIX_ATTEMPTS)..."
    "$fixfn" "$rc" || return "$rc"
    info "Re-running the command..."
  done
}

# log_has PATTERN [LINES] : did the last LINES lines of the lab log match?
log_has() { [ -n "${LAB_LOG:-}" ] && tail -n "${2:-200}" "$LAB_LOG" | grep -qE "$1"; }

# ---- misc helpers ----------------------------------------------------------
have()   { command -v "$1" >/dev/null 2>&1; }
die()    { note_fail "$*"; exit 1; }
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; export PATH; }
path_without() { printf '%s' "$PATH" | tr ':' '\n' | grep -v "^$1" | paste -sd: -; }
version_ge()   { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]; }
version_from_path() { basename "$1" | grep -oE '[0-9]+(\.[0-9]+)+' | tail -n1; }

save_detected() {   # save_detected KEY VALUE  -> state/detected.env
  local f="$STATE_DIR/detected.env" tmp
  tmp=$(mktemp "$STATE_DIR/.det.XXXXXX")
  [ -f "$f" ] && grep -v "^$1=" "$f" > "$tmp"
  printf '%s="%s"\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$f"
  export "$1=$2"
}

lab_workdir() {   # lab_workdir NAME : create and enter the lab's work directory
  LAB_WORK="$LAB_WORKDIR_BASE/$1"
  mkdir -p "$LAB_WORK" "$RESULTS_DIR/$1" || die "Cannot create $LAB_WORK"
  LAB_RESULTS="$RESULTS_DIR/$1"
  show "cd $LAB_WORK"
  cd "$LAB_WORK" || die "Cannot enter $LAB_WORK"
}

# background helpers started by a lab (feeders etc.). Killed when the lab ends.
BG_PIDS=()
bg_track() { BG_PIDS+=("$1"); }
cleanup_background() {
  local p
  for p in "${BG_PIDS[@]:-}"; do
    [ -n "$p" ] && kill "$p" 2>/dev/null
  done
  [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
  return 0
}

write_status() { [ -n "${STATUS_FILE:-}" ] && printf '%s\n' "$1" > "$STATUS_FILE"; return 0; }
