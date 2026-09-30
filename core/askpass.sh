#!/usr/bin/env bash
# core/askpass.sh - SUDO_ASKPASS helper.
# sudo runs this program and reads the password from its stdout.
# It opens the authentication window (askpass-ui.sh) and waits for the
# password on a private FIFO (mode 600, memory only, deleted right after).

RUNNER_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
. "$RUNNER_DIR/core/common.sh"
. "$RUNNER_DIR/core/terminal.sh"

attempt_file="$STATE_DIR/askpass.attempt"
n=$(( $(cat "$attempt_file" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$attempt_file"

fifo="$STATE_DIR/askpass.$$.fifo"
rm -f "$fifo"
mkfifo -m 600 "$fifo" || exit 1
exec 3<>"$fifo"          # open read/write so nothing blocks on open()

cleanup() { exec 3>&- 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT

if ! spawn_terminal "ADMINISTRATOR AUTHENTICATION" "$RUNNER_DIR/core/askpass-ui.sh" "$fifo" "$n"; then
  # No graphical terminal: ask on the controlling terminal instead.
  if [ -r /dev/tty ]; then
    IFS= read -rs -p "[sudo] password for $(id -un) (attempt $n): " pw </dev/tty
    echo >/dev/tty
    printf '%s\n' "$pw"
    exit 0
  fi
  exit 1
fi

pw=""
# Wait up to 5 minutes for the auth window. If it is closed or times out, sudo fails cleanly.
if ! IFS= read -r -t 300 pw <&3; then
  exit 1
fi
[ "$pw" = "__CANCEL__" ] && exit 1
printf '%s\n' "$pw"
exit 0
