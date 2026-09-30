#!/usr/bin/env bash
# core/terminal.sh - open new terminal windows for lab execution and authentication

has_display() { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }

detect_terminal_emulator() {
  if [ -n "${TERM_EMULATOR:-}" ] && have "$TERM_EMULATOR"; then return 0; fi
  local t
  for t in gnome-terminal xfce4-terminal konsole mate-terminal tilix lxterminal terminator xterm x-terminal-emulator; do
    if have "$t"; then TERM_EMULATOR=$t; return 0; fi
  done
  TERM_EMULATOR=""
  return 1
}

# spawn_terminal TITLE SCRIPT [ARGS...]
# Opens a new window that runs: bash SCRIPT ARGS...  Returns 1 if no window could be opened.
spawn_terminal() {
  local title=$1; shift
  has_display || return 1
  detect_terminal_emulator || return 1
  local emu=$TERM_EMULATOR
  if [ "$emu" = x-terminal-emulator ]; then
    emu=$(basename "$(readlink -f "$(command -v x-terminal-emulator)")")
  fi
  local cmdstr
  cmdstr=$(printf '%q ' bash "$@")
  case "$emu" in
    gnome-terminal*)  gnome-terminal --title="$title" -- bash "$@" ;;
    mate-terminal)    mate-terminal --title="$title" -x bash "$@" ;;
    xfce4-terminal*)  xfce4-terminal --title="$title" -x bash "$@" ;;
    konsole)          konsole --title "$title" -e bash "$@" ;;
    tilix)            tilix --title="$title" -e "$cmdstr" ;;
    lxterminal)       lxterminal --title="$title" -e "$cmdstr" ;;
    terminator)       terminator --title="$title" -e "$cmdstr" ;;
    xterm|uxterm|rxvt*|urxvt*) "$emu" -T "$title" -e bash "$@" ;;
    *)                "$emu" -e bash "$@" ;;
  esac >/dev/null 2>&1 &
  disown 2>/dev/null || true
  return 0
}
