#!/usr/bin/env bash
# core/sudo.sh - administrator authentication
#
# The runner never stores or guesses your password. When a step needs sudo it
# runs `sudo -A -v`. sudo then calls core/askpass.sh, which opens a small
# authentication terminal where you type the password. sudo checks it, caches
# the credential for this lab terminal, and the lab continues.

ensure_sudo() {
  if ! have sudo; then
    note_fail "sudo is not installed"
    return 1
  fi
  if sudo -n true 2>/dev/null; then
    ok "Administrator access already authenticated"
    sudo_keepalive_start
    return 0
  fi
  warn "Administrator permission required."
  note_warn "Administrator password required. Opening authentication terminal..."
  export SUDO_ASKPASS="$CORE_DIR/askpass.sh"
  rm -f "$STATE_DIR/askpass.attempt"
  chmod +x "$CORE_DIR/askpass.sh" "$CORE_DIR/askpass-ui.sh" 2>/dev/null
  if sudo -A -v 2>/dev/null && sudo -n true 2>/dev/null; then
    note_ok "Password accepted. Administrator access granted."
    sudo_keepalive_start
    return 0
  fi
  note_fail "Authentication failed or cancelled."
  return 1
}

# refresh the sudo timestamp in the background so long labs do not ask again
sudo_keepalive_start() {
  [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null && return 0
  ( while sudo -n -v 2>/dev/null; do sleep 50; done ) >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
}

# sudo_run CMD... : authenticate if needed, then run the command with sudo
sudo_run() {
  ensure_sudo || return 1
  run sudo "$@"
}
