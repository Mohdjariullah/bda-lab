#!/usr/bin/env bash
# core/sidewin.sh RCFILE LOGFILE LABEL CMD...  - a second terminal for a lab.
# Used when the manual runs two programs in two terminals (Lab 10: the Kafka
# consumer in one, the producer in the other). The window looks like a normal
# terminal: the prompt, the command (LABEL), its output. The output is also
# copied to LOGFILE so the lab can check it. The program runs until it ends
# or Ctrl+C is pressed; after that the window is a normal shell.

RUNNER_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
rc=$1; log=$2; label=$3; shift 3
. "$RUNNER_DIR/core/common.sh"
RAW_OUTPUT=1
# the lab's environment and folder (written by labshell.sh)
. "$rc" 2>/dev/null
clear
printf '%s%s\n' "$(_lab_prompt)" "$label"
trap : INT          # Ctrl+C stops the program, not this window
"$@" 2>&1 | tee "$log"
trap - INT
exec bash --rcfile "$rc" -i
