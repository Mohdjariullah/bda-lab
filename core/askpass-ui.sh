#!/usr/bin/env bash
# core/askpass-ui.sh FIFO ATTEMPT - the authentication window.
# Reads the password (hidden) and sends it to askpass.sh through the FIFO.
# The window closes by itself afterwards.

fifo=$1
n=${2:-1}

send() { printf '%s\n' "$1" > "$fifo" 2>/dev/null; }
trap 'send __CANCEL__; exit 1' INT TERM HUP

echo "============================================================"
echo "        ADMINISTRATOR AUTHENTICATION"
echo "============================================================"
echo
echo "The lab needs to run a command with sudo."
echo "Type your Linux password and press ENTER."
echo "This window closes automatically. The lab continues in its own window."
echo
if [ "$n" -gt 1 ]; then
  echo "[!] The previous password was not accepted. Attempt $n of 3."
  echo
fi
echo "(Press ENTER with an empty password to cancel.)"
echo

IFS= read -rs -p "[sudo] password for $(id -un): " pw
echo
if [ -z "$pw" ]; then
  send __CANCEL__
  echo "Cancelled."
  sleep 1
  exit 1
fi
send "$pw"
pw=""
echo
echo "[✓] Password sent to the lab terminal. Closing..."
sleep 1
exit 0
