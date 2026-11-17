#!/usr/bin/env bash
# core/detect.sh - find installations, pick ONE copy, set the environment.
#
# Default (REUSE_INSTALLED=0): only two places count.
#   1. CFG_<TOOL>_HOME from config/environment.conf
#   2. the runner's own copy in $STACK_DIR (installed by Setup, versions that
#      are tested together)
# Other copies on the PC (in /opt, /usr/local, ~/hadoop ...) are ignored, so a
# wrong version or a broken configuration there cannot break a lab.
#
# With REUSE_INSTALLED=1 the search continues (first valid one wins):
#   2. DETECTED_<TOOL>_HOME cached in state/detected.env (a choice made earlier)
#   3. <TOOL>_HOME inherited from the shell, if it points to a real install
#   4. the executable found on PATH
#   5. a filesystem search; with several copies the highest version wins
#
# Tools are always executed through their chosen home (absolute path), so a
# wrong copy earlier in PATH cannot interfere.

_tool_spec() {   # sets T_VAR T_BIN T_PROBE for a tool name
  case "$1" in
    hadoop) T_VAR=HADOOP_HOME; T_BIN=bin/hadoop;               T_PROBE="version";   T_MARK="share/hadoop" ;;
    pig)    T_VAR=PIG_HOME;    T_BIN=bin/pig;                  T_PROBE="-version";  T_MARK="pig-*.jar" ;;
    hive)   T_VAR=HIVE_HOME;   T_BIN=bin/hive;                 T_PROBE="--version"; T_MARK="lib/hive-exec-*.jar" ;;
    spark)  T_VAR=SPARK_HOME;  T_BIN=bin/spark-submit;         T_PROBE="--version"; T_MARK="jars/spark-core_*.jar" ;;
    kafka)  T_VAR=KAFKA_HOME;  T_BIN=bin/kafka-server-start.sh; T_PROBE="";         T_MARK="libs/kafka_*.jar" ;;
    *) return 1 ;;
  esac
}

# stack_home NAME : where Setup puts the runner's own copy of a tool
stack_home() {
  case "$1" in
    hadoop) echo "$STACK_DIR/hadoop-$HADOOP_VER" ;;
    pig)    echo "$STACK_DIR/pig-$PIG_VER" ;;
    hive)   echo "$STACK_DIR/apache-hive-$HIVE_VER-bin" ;;
    spark)  echo "$STACK_DIR/spark-$SPARK_VER-bin-hadoop3" ;;
    kafka)  echo "$STACK_DIR/kafka_$KAFKA_SCALA_VER-$KAFKA_INSTALL_VER" ;;
    java)   echo "$STACK_DIR/jdk8" ;;
  esac
}

# a real installation has the launcher AND the tool's jars (a pip/npm shim in
# /usr/local/bin has only the launcher, so /usr/local is not a valid home)
_valid_home() {
  [ -n "$1" ] && [ -x "$1/$2" ] || return 1
  [ -z "${T_MARK:-}" ] || compgen -G "$1/$T_MARK" >/dev/null 2>&1
}
_home_of_bin() { local p; p=$(readlink -f "$1"); dirname "$(dirname "$p")"; }

# find_bins PATTERN : all executables matching a find -path pattern under SEARCH_ROOTS
find_bins() {
  local pat=$1 root
  for root in $SEARCH_ROOTS; do
    [ -d "$root" ] || continue
    find -L "$root" -maxdepth 6 \
      \( -name .cache -o -name .git -o -name node_modules -o -name snap -o -name .local \) -prune -o \
      -type f -path "$pat" -perm -u+x -print 2>/dev/null
  done | sort -u
}

# find_installs BINREL : candidate home dirs, highest version first (ties: newest file)
find_installs() {
  local binrel=$1 found f home v
  found=$(find_bins "*/$binrel")
  [ -n "$found" ] || return 1
  while IFS= read -r f; do
    home=$(_home_of_bin "$f")
    _valid_home "$home" "$binrel" || continue
    v=$(version_from_path "$home"); [ -n "$v" ] || v=0
    printf '%s\t%s\t%s\n' "$v" "$(stat -c %Y "$home/$binrel" 2>/dev/null || echo 0)" "$home"
  done <<< "$found" | sort -t$'\t' -k1,1Vr -k2,2nr | awk -F'\t' '!seen[$3]++ {print $3}'
}

# locate_home NAME : sets LOCATED_HOME to the chosen home (empty if none),
# plus LOCATE_SOURCE and LOCATE_CANDIDATES. Returns 1 when nothing was found.
locate_home() {
  local name=$1
  LOCATED_HOME=""; LOCATE_SOURCE=""; LOCATE_CANDIDATES=""
  _tool_spec "$name" || return 1
  local cfgvar="CFG_$T_VAR" cachevar="DETECTED_$T_VAR" cur="${!T_VAR:-}"
  if _valid_home "${!cfgvar:-}" "$T_BIN";   then LOCATE_SOURCE=config; LOCATED_HOME=${!cfgvar};   return 0; fi
  local own; own=$(stack_home "$name")
  if _valid_home "$own" "$T_BIN";           then LOCATE_SOURCE="own copy"; LOCATED_HOME=$own;     return 0; fi
  [ "${REUSE_INSTALLED:-0}" = 1 ] || return 1
  if _valid_home "${!cachevar:-}" "$T_BIN"; then LOCATE_SOURCE=cache;  LOCATED_HOME=${!cachevar}; return 0; fi
  if _valid_home "$cur" "$T_BIN";           then LOCATE_SOURCE=env;    LOCATED_HOME=$cur;         return 0; fi
  local p h
  p=$(command -v "$(basename "$T_BIN")" 2>/dev/null)
  if [ -n "$p" ]; then
    h=$(_home_of_bin "$p")
    if _valid_home "$h" "$T_BIN"; then LOCATE_SOURCE=path; LOCATED_HOME=$h; return 0; fi
  fi
  LOCATE_CANDIDATES=$(find_installs "$T_BIN") || return 1
  LOCATE_SOURCE=search
  LOCATED_HOME=$(printf '%s\n' "$LOCATE_CANDIDATES" | head -n1)
}

# ensure_tool NAME : resolve the installation, export <TOOL>_HOME + PATH, then
# run the tool's version command once to prove it starts.
ensure_tool() {
  local name=$1
  _tool_spec "$name" || return 1
  local binname; binname=$(basename "$T_BIN")
  local home
  check "$name"
  locate_home "$name"; home=$LOCATED_HOME
  if [ -z "$home" ]; then
    note_fail "$name is not installed. Type S in the menu (Setup) to install it."
    return 1
  fi
  if [ -n "$LOCATE_CANDIDATES" ] && [ "$(printf '%s\n' "$LOCATE_CANDIDATES" | wc -l)" -gt 1 ]; then
    warn "Multiple $name installations found:"
    printf '%s\n' "$LOCATE_CANDIDATES" | sed 's/^/      /'
    fixmsg "Using the highest version: $home"
  fi
  export "$T_VAR=$home"
  path_prepend "$home/bin"
  [ -d "$home/sbin" ] && path_prepend "$home/sbin"
  save_detected "DETECTED_$T_VAR" "$home"
  if [ -n "$T_PROBE" ]; then
    run "$binname" $T_PROBE || { note_fail "$name does not start ($home). Type S in the menu (Setup): it replaces a damaged copy."; return 1; }
  fi
  note_ok "$name: $home  ($LOCATE_SOURCE)"
}

# ---- Java ------------------------------------------------------------------
_java_major() {
  # not "head -n1": a JVM prints "Picked up _JAVA_OPTIONS/JAVA_TOOL_OPTIONS: ..." before the version line
  local v; v=$("$1/bin/java" -version 2>&1 | grep -E 'version "' | head -n1 | grep -oE '"[^"]+"' | head -n1 | tr -d '"')
  case "$v" in
    1.*) echo "$v" | cut -d. -f2 ;;
    *)   echo "$v" | cut -d. -f1 ;;
  esac
}
# list_javas : "MAJOR<TAB>HOME" for every JDK (java + javac) that really runs.
# The runner's own JDK comes first, so it wins when two have the same version.
list_javas() {
  {
    echo "$(stack_home java)"
    [ -n "${CFG_JAVA_HOME:-}" ] && echo "$CFG_JAVA_HOME"
    ls -d /usr/lib/jvm/*/ 2>/dev/null | sed 's:/$::'
    if [ "${REUSE_INSTALLED:-0}" = 1 ]; then
      find_bins '*/bin/javac' | while IFS= read -r f; do _home_of_bin "$f"; done
      local p; p=$(command -v javac 2>/dev/null) && _home_of_bin "$p"
    fi
  } | while IFS= read -r h; do
        h=$(readlink -f "$h" 2>/dev/null)
        [ -n "$h" ] && [ -x "$h/bin/javac" ] && [ -x "$h/bin/java" ] && echo "$h"
      done | awk '!seen[$0]++' | while IFS= read -r h; do
        local m; m=$(_java_major "$h")
        # a JDK directory whose java does not start (half removed package) is skipped
        [ -n "$m" ] && printf '%s\t%s\n' "$m" "$h"
      done
}

# ensure_java [PREFS] : PREFS is a list of major versions in order of preference.
ensure_java() {
  local prefs="${1:-8 11 17 21}"
  check "Java (preferred versions: $prefs)"
  local chosen="" src="" list m h
  if [ -n "${CFG_JAVA_HOME:-}" ] && [ -x "$CFG_JAVA_HOME/bin/javac" ]; then
    chosen=$(readlink -f "$CFG_JAVA_HOME"); src=config
  else
    list=$(list_javas)
    if [ -z "$list" ]; then
      note_fail "No JDK found. Type S in the menu (Setup) to install Java 8."
      return 1
    fi
    for m in $prefs; do
      h=$(printf '%s\n' "$list" | awk -F'\t' -v m="$m" '$1==m {print $2; exit}')
      [ -n "$h" ] && { chosen=$h; src="Java $m"; break; }
    done
    if [ -z "$chosen" ]; then
      chosen=$(printf '%s\n' "$list" | sort -n | head -n1 | cut -f2); src="only JDK available"
    fi
  fi
  export JAVA_HOME=$chosen
  path_prepend "$JAVA_HOME/bin"
  save_detected DETECTED_JAVA_HOME "$chosen"
  JAVA_MAJOR=$(_java_major "$JAVA_HOME")
  run java -version  || { note_fail "java does not start ($JAVA_HOME)"; return 1; }
  run javac -version || { note_fail "javac does not start ($JAVA_HOME)"; return 1; }
  note_ok "Java $JAVA_MAJOR: $JAVA_HOME"
}

# ---- Python ----------------------------------------------------------------
ensure_python() {
  check "Python"
  if ! run python3 --version; then
    note_fail "python3 is not installed on this PC (Ubuntu always has it). Install it: sudo apt install python3"
    return 1
  fi
  path_prepend "$HOME/.local/bin"
  if ! python3 -m pip --version >/dev/null 2>&1; then
    # Ubuntu ships python3 without pip. get-pip.py installs it for this user only: no password needed.
    [ "$AUTO_INSTALL_PY" = 1 ] || { warn "pip is not available and AUTO_INSTALL_PY=0"; return 0; }
    fixmsg "pip is missing: installing it for this user (no administrator rights needed)"
    local gp="$STATE_DIR/get-pip.py"
    if fetch_url https://bootstrap.pypa.io/get-pip.py "$gp"; then
      run python3 "$gp" --user --quiet || run python3 "$gp" --user --quiet --break-system-packages \
        || warn "get-pip.py failed"
    else
      warn "Could not download get-pip.py (no internet?)"
    fi
    rm -f "$gp"
  fi
  run python3 -m pip --version || warn "pip is not available: missing Python packages cannot be installed"
  note_ok "Python $(python3 --version 2>&1 | awk '{print $2}')"
}

# fetch_url URL DEST : download with whatever this PC has (curl, wget or python3). No resume.
fetch_url() {
  if have curl; then curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1"
  elif have wget; then wget -q --tries=3 --timeout=30 -O "$2" "$1"
  else python3 - "$1" "$2" <<'PY'
import sys, urllib.request
urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
  fi
}

# ensure_pymods module[:pip_pkg[:apt_pkg]] ...
ensure_pymods() {
  local spec mod pip apt missing=0
  for spec in "$@"; do
    IFS=: read -r mod pip apt <<< "$spec"
    pip=${pip:-$mod}
    check "Python module: $mod"
    if run python3 -c "import $mod; print('$mod', getattr($mod, '__version__', 'ok'))"; then
      ok "$mod available"; continue
    fi
    warn "Missing package: $mod"
    if [ "$AUTO_INSTALL_PY" != 1 ]; then missing=1; continue; fi
    fixmsg "Installing $pip"
    run python3 -m pip install --user "$pip" \
      || run python3 -m pip install --user --break-system-packages "$pip"
    if run python3 -c "import $mod"; then
      note_fix "Installed $mod"
    else
      note_fail "Could not install $mod"; missing=1
    fi
  done
  return $missing
}

# ---- environment scan (used by the launcher menu) --------------------------
scan_environment() {
  local t h
  ENV_JAVA=0 ENV_PYTHON=0 ENV_HADOOP=0 ENV_HDFSCONF=0 ENV_PIG=0 ENV_HIVE=0 ENV_SPARK=0 ENV_KAFKA=0
  # Java 8 is what Hadoop 3.3, Hive 3.1 and Pig 0.17 are built for
  if [ -n "${CFG_JAVA_HOME:-}" ] && [ -x "$CFG_JAVA_HOME/bin/javac" ]; then
    ENV_JAVA=1
  else
    h=$(list_javas | awk -F'\t' '$1==8 {print $2; exit}')
    [ -n "$h" ] && { ENV_JAVA=1; save_detected DETECTED_JAVA_HOME "$h"; }
  fi
  have python3 && ENV_PYTHON=1
  for t in hadoop pig hive spark kafka; do
    _tool_spec "$t"
    locate_home "$t"; h=$LOCATED_HOME
    if [ -n "$h" ]; then
      eval "ENV_${t^^}=1"
      save_detected "DETECTED_$T_VAR" "$h"
      export "$T_VAR=$h"
    fi
  done
  if [ -n "${HADOOP_HOME:-}" ] && grep -qs 'fs.defaultFS' "$HADOOP_HOME/etc/hadoop/core-site.xml"; then
    ENV_HDFSCONF=1
  fi
}
