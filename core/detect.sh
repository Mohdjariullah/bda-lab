#!/usr/bin/env bash
# core/detect.sh - choose ONE installation of every tool and set the environment.
#
# A tool is used from (first valid one wins):
#   1. CFG_<TOOL>_HOME from config/environment.conf (forced by hand)
#   2. the runner's own copy in $STACK_DIR, when Setup had to download one
#   3. DETECTED_<TOOL>_HOME in state/detected.env: a copy that was already on
#      this PC and that Setup has STARTED AND TESTED
#
# Finding and testing the copies that are already on the PC is Setup's job
# (core/setup/run.sh). It looks where the shell says the tool is (HADOOP_HOME,
# JAVA_HOME ...), then at the command on PATH, then searches the disk. Only a
# copy that really starts and has a usable version is taken; if there is none,
# Setup downloads the runner's own copy. With REUSE_INSTALLED=0 Setup skips
# the copies on the PC and always uses its own.
#
# Tools are always executed through their chosen home, with the runner's own
# configuration directories, so the settings of the PC cannot interfere.

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
  local cfgvar="CFG_$T_VAR" cachevar="DETECTED_$T_VAR"
  if _valid_home "${!cfgvar:-}" "$T_BIN";   then LOCATE_SOURCE=config; LOCATED_HOME=${!cfgvar};   return 0; fi
  local own; own=$(stack_home "$name")
  if _valid_home "$own" "$T_BIN";           then LOCATE_SOURCE="own copy"; LOCATED_HOME=$own;     return 0; fi
  if _valid_home "${!cachevar:-}" "$T_BIN"; then LOCATE_SOURCE="already on this PC, tested"; LOCATED_HOME=${!cachevar}; return 0; fi
  return 1
}

# candidate_homes NAME : "HOME<TAB>WHERE IT WAS FOUND" for every copy of the tool
# on this PC, best guess first: the shell variable, the command on PATH, a disk search.
candidate_homes() {
  local name=$1 hint p h own
  _tool_spec "$name" || return 1
  own=$(readlink -f "$(stack_home "$name")" 2>/dev/null)
  {
    hint="HINT_$T_VAR"; hint=${!hint:-}
    [ -n "$hint" ] && printf '%s\t%s\n' "$hint" "$T_VAR in your shell"
    p=$(command -v "$(basename "$T_BIN")" 2>/dev/null)
    [ -n "$p" ] && printf '%s\t%s\n' "$(_home_of_bin "$p")" "$(basename "$T_BIN") on PATH"
    find_installs "$T_BIN" 2>/dev/null | while IFS= read -r h; do printf '%s\t%s\n' "$h" "found on disk"; done
  } | while IFS=$'\t' read -r h p; do
        h=$(readlink -f "$h" 2>/dev/null)
        [ -n "$h" ] && [ "$h" != "$own" ] && printf '%s\t%s\n' "$h" "$p"
      done | awk -F'\t' '!seen[$1]++'
}

# prepare_tool_conf NAME : point the tool at the runner's private configuration
prepare_tool_conf() {
  case "$1" in
    hadoop) build_hadoop_conf ;;
    hive)
      # Hive reads $HIVE_HOME/conf/hive-site.xml when the private directory has none,
      # so the private one states the lab's settings: embedded Derby in the work directory
      mkdir -p "$STATE_DIR/hive-conf"
      _xml "$STATE_DIR/hive-conf/hive-site.xml" \
        "javax.jdo.option.ConnectionURL=jdbc:derby:;databaseName=metastore_db;create=true" \
        "javax.jdo.option.ConnectionDriverName=org.apache.derby.jdbc.EmbeddedDriver" \
        "hive.metastore.uris=" \
        "hive.metastore.warehouse.dir=/user/hive/warehouse" \
        "hive.exec.local.scratchdir=$LAB_WORKDIR_BASE/hive-scratch" \
        "hive.querylog.location=$LAB_WORKDIR_BASE/hive-scratch"
      export HIVE_CONF_DIR="$STATE_DIR/hive-conf" ;;
    spark)
      mkdir -p "$STATE_DIR/spark-conf"; export SPARK_CONF_DIR="$STATE_DIR/spark-conf" ;;
    kafka)
      # kafka-run-class.sh writes logs into the installation folder by default (read-only when root-owned)
      mkdir -p "$LAB_WORKDIR_BASE/kafka-data/logs"; export LOG_DIR="$LAB_WORKDIR_BASE/kafka-data/logs" ;;
  esac
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
  # the runner's private configuration must be in place BEFORE the tool is
  # started: the PC's own files (hadoop-env.sh with an old JAVA_HOME, a
  # hive-site.xml for MySQL, a cluster spark-defaults.conf) would break it
  prepare_tool_conf "$name"
  if [ -n "$T_PROBE" ]; then
    if ! run "$binname" $T_PROBE; then
      # forget this copy: the launcher then runs Setup, which tests every copy again
      [ "$LOCATE_SOURCE" = config ] || save_detected "DETECTED_$T_VAR" ""
      note_fail "$name does not start ($home)"
      return 1
    fi
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
    if [ "${REUSE_INSTALLED:-1}" = 1 ]; then
      [ -n "${DETECTED_JAVA_HOME:-}" ] && echo "$DETECTED_JAVA_HOME"
      [ -n "${HINT_JAVA_HOME:-}" ] && echo "$HINT_JAVA_HOME"
      ls -d /usr/lib/jvm/*/ 2>/dev/null | sed 's:/$::'
      local p; p=$(command -v javac 2>/dev/null) && _home_of_bin "$p"
      # the disk search is slow, so only Setup does it (JAVA_SEARCH=1) and remembers the result
      if [ "${JAVA_SEARCH:-0}" = 1 ]; then
        find_bins '*/bin/javac' | while IFS= read -r f; do _home_of_bin "$f"; done
      fi
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
  # the HDFS configuration is the runner's own (state/hadoop-conf), written when a lab needs it
  ENV_HDFSCONF=$ENV_HADOOP
}
