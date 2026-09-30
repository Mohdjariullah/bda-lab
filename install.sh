#!/usr/bin/env bash
# install.sh - one-command install of the Big Data Lab Runner from a git clone.
#
#   git clone https://github.com/Mohdjariullah/bda-lab.git
#   cd bda-lab
#   ./install.sh            # makes everything executable, adds a desktop launcher, opens the menu
#
# It changes nothing on the system. It only sets file permissions inside this
# folder and writes one .desktop launcher for your user.
set -e
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "Big Data Lab Runner - setup"
for t in bash tar timeout; do
  command -v "$t" >/dev/null 2>&1 || { echo "Missing required tool: $t"; exit 1; }
done

chmod +x "$HERE/lab-runner" "$HERE/core"/*.sh "$HERE/core/diag/run.sh" \
         "$HERE/labs"/*/run.sh "$HERE/labs/lab04"/*/run.sh 2>/dev/null || true
mkdir -p "$HERE/logs" "$HERE/results" "$HERE/state"
chmod 700 "$HERE/state" 2>/dev/null || true

# desktop launcher (double-click from the Files app or the app grid)
apps="$HOME/.local/share/applications"
mkdir -p "$apps"
cat > "$apps/bigdata-lab-runner.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Big Data Lab Runner
Comment=Run the Big Data Analytics labs (Hadoop, Pig, Hive, Spark, Kafka, MongoDB)
Exec=bash -lc 'cd "$HERE" && ./lab-runner; exec bash'
Path=$HERE
Terminal=true
Categories=Education;Development;
Icon=utilities-terminal
DESK
chmod +x "$apps/bigdata-lab-runner.desktop" 2>/dev/null || true
update-desktop-database "$apps" >/dev/null 2>&1 || true

# also drop a clickable copy on the Desktop if there is one
if [ -d "$HOME/Desktop" ]; then
  cp "$apps/bigdata-lab-runner.desktop" "$HOME/Desktop/" 2>/dev/null || true
  chmod +x "$HOME/Desktop/bigdata-lab-runner.desktop" 2>/dev/null || true
  # GNOME 42+ needs the file "trusted"
  command -v gio >/dev/null 2>&1 && gio set "$HOME/Desktop/bigdata-lab-runner.desktop" metadata::trusted true 2>/dev/null || true
fi

echo "Installed."
echo "  - Start it now:            cd \"$HERE\" && ./lab-runner"
echo "  - Or open \"Big Data Lab Runner\" from the app grid / Desktop."
echo

if [ -t 0 ] && [ -t 1 ]; then
  printf "Open the menu now? [Y/n] "
  read -r a
  case "$a" in n|N) exit 0 ;; esac
  exec "$HERE/lab-runner"
fi
