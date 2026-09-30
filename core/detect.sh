#!/usr/bin/env bash
# core/detect.sh - find installations, pick ONE copy, set the environment.
#
# Selection order for every tool (first valid one wins):
#   1. CFG_<TOOL>_HOME from config/environment.conf
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

# ensure_tool NAME : run the plain command first (like the lab would), then
# resolve the installation, export <TOOL>_HOME + PATH, and re-run if it failed.
ensure_tool() {
  local name=$1
  _tool_spec "$name" || return 1
  local binname; binname=$(basename "$T_BIN")
  local cur="${!T_VAR:-}" probe_rc=0 home
  check "$name"
  if [ -n "$T_PROBE" ]; then
    run "$binname" $T_PROBE; probe_rc=$?
  else
    run bash -c "type $binname"; probe_rc=$?
  fi
  locate_home "$name"; home=$LOCATED_HOME
  if [ -z "$home" ]; then
    note_fail "$name installation not detected. Searched: $SEARCH_ROOTS"
    return 1
  fi
  # report what was wrong
  if [ -n "$cur" ] && [ "$(readlink -f "$cur")" != "$(readlink -f "$home")" ]; then
    if _valid_home "$cur" "$T_BIN"; then
      warn "$T_VAR ($cur) is not the selected installation."
    else
      fail "$T_VAR points to a missing or broken directory: $cur"
    fi
  fi
  local p; p=$(command -v "$binname" 2>/dev/null)
  if [ -n "$p" ] && [ "$(readlink -f "$p")" != "$(readlink -f "$home/$T_BIN")" ]; then
    warn "$binname on PATH ($p) is a different copy than $home/$T_BIN"
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
  if [ "$probe_rc" -ne 0 ] || [ "$(readlink -f "${cur:-/nonexistent}")" != "$(readlink -f "$home")" ]; then
    fixmsg "export $T_VAR=$home"
    fixmsg "export PATH=$home/bin:\$PATH  (source: $LOCATE_SOURCE)"
    if [ "$probe_rc" -ne 0 ] && [ -n "$T_PROBE" ]; then
      info "Re-running:"
      run "$home/$T_BIN" $T_PROBE || { note_fail "$name still fails after the fix"; return 1; }
    fi
  fi
  note_ok "$name: $home"
}

# ---- Java ------------------------------------------------------------------
_java_major() {
  local v; v=$("$1/bin/java" -version 2>&1 | head -n1 | grep -oE '"[^"]+"' | tr -d '"')
  case "$v" in
    1.*) echo "$v" | cut -d. -f2 ;;
    *)   echo "$v" | cut -d. -f1 ;;
  esac
}
# list_javas : "MAJOR<TAB>HOME" for every JDK (java + javac) found
list_javas() {
  {
    ls -d /usr/lib/jvm/*/ 2>/dev/null | sed 's:/$::'
    find_bins '*/bin/javac' | while IFS= read -r f; do _home_of_bin "$f"; done
    [ -n "${JAVA_HOME:-}" ] && echo "$JAVA_HOME"
    [ -n "${CFG_JAVA_HOME:-}" ] && echo "$CFG_JAVA_HOME"
    local p; p=$(command -v javac 2>/dev/null) && _home_of_bin "$p"
  } | while IFS= read -r h; do
        h=$(readlink -f "$h" 2>/dev/null)
        [ -n "$h" ] && [ -x "$h/bin/javac" ] && [ -x "$h/bin/java" ] && echo "$h"
      done | sort -u | while IFS= read -r h; do
        printf '%s\t%s\n' "$(_java_major "$h")" "$h"
      done
}

# ensure_java [PREFS] : PREFS is a list of major versions in order of preference.
ensure_java() {
  local prefs="${1:-8 11 17 21}"
  check "Java (preferred versions: $prefs)"
  run java -version;  local rc1=$?
  run javac -version; local rc2=$?
  local cur="${JAVA_HOME:-}" chosen="" src="" list m h
  if [ -n "${CFG_JAVA_HOME:-}" ] && [ -x "$CFG_JAVA_HOME/bin/javac" ]; then
    chosen=$(readlink -f "$CFG_JAVA_HOME"); src=config
  else
    list=$(list_javas)
    if [ -z "$list" ] && [ "${JAVA_NEED_JDK:-1}" = 0 ]; then
      # Spark and Kafka only need a runtime: accept a plain JRE
      local jb; jb=$(command -v java 2>/dev/null) || jb=$(find_bins '*/bin/java' | head -n1)
      if [ -n "$jb" ]; then
        list=$(printf '%s\t%s\n' "$(_java_major "$(_home_of_bin "$jb")")" "$(_home_of_bin "$jb")")
        warn "No JDK (javac) found, using the Java runtime at $(_home_of_bin "$jb")"
      fi
    fi
    if [ -z "$list" ]; then
      note_fail "No JDK found (java + javac). Install one, e.g.: sudo apt install openjdk-8-jdk"
      return 1
    fi
    for m in $prefs; do
      h=$(printf '%s\n' "$list" | awk -F'\t' -v m="$m" '$1==m {print $2; exit}')
      [ -n "$h" ] && { chosen=$h; src="preferred Java $m"; break; }
    done
    if [ -z "$chosen" ]; then
      chosen=$(printf '%s\n' "$list" | sort -n | head -n1 | cut -f2); src="only JDK available"
    fi
    # keep the current JAVA_HOME when it is valid and has the same major version
    if [ -n "$cur" ] && [ -x "$cur/bin/java" ] && [ "$(_java_major "$cur")" = "$(_java_major "$chosen")" ]; then
      chosen=$(readlink -f "$cur"); src=env
    fi
    if [ "$(printf '%s\n' "$list" | wc -l)" -gt 1 ]; then
      warn "Multiple JDKs found:"
      printf '%s\n' "$list" | awk -F'\t' '{printf "      Java %-3s %s\n", $1, $2}'
    fi
  fi
  [ -n "$cur" ] && [ ! -x "$cur/bin/java" ] && fail "JAVA_HOME is invalid: $cur"
  export JAVA_HOME=$chosen
  path_prepend "$JAVA_HOME/bin"
  save_detected DETECTED_JAVA_HOME "$chosen"
  JAVA_MAJOR=$(_java_major "$JAVA_HOME")
  if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ] || [ "$(readlink -f "${cur:-/nonexistent}")" != "$chosen" ]; then
    fixmsg "export JAVA_HOME=$JAVA_HOME  ($src)"
    fixmsg "export PATH=\$JAVA_HOME/bin:\$PATH"
    if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
      info "Re-running:"
      run java -version
      if [ "${JAVA_NEED_JDK:-1}" = 0 ] && [ ! -x "$JAVA_HOME/bin/javac" ]; then
        info "javac is not needed for this lab"
      else
        run javac -version || { note_fail "javac still not working"; return 1; }
      fi
    fi
  fi
  note_ok "Java $JAVA_MAJOR: $JAVA_HOME"
}

# ---- Python ----------------------------------------------------------------
ensure_python() {
  check "Python"
  if ! run python3 --version; then
    fixmsg "python3 is missing, installing"
    ensure_sudo && run sudo apt-get install -y python3 python3-pip || return 1
  fi
  if ! run python3 -m pip --version; then
    warn "pip is not available"
    if [ "$AUTO_INSTALL_PY" = 1 ]; then
      fixmsg "Installing python3-pip"
      ensure_sudo && run sudo apt-get install -y python3-pip
    fi
  fi
  path_prepend "$HOME/.local/bin"
  note_ok "Python $(python3 --version 2>&1 | awk '{print $2}')"
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
      || run python3 -m pip install --user --break-system-packages "$pip" \
      || { [ -n "$apt" ] && ensure_sudo && run sudo apt-get install -y "$apt"; }
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
  ENV_JAVA=0 ENV_PYTHON=0 ENV_HADOOP=0 ENV_HDFSCONF=0 ENV_PIG=0 ENV_MONGO=0 ENV_HIVE=0 ENV_SPARK=0 ENV_KAFKA=0
  if [ -x "${DETECTED_JAVA_HOME:-}/bin/javac" ]; then
    ENV_JAVA=1
  else
    h=$(list_javas | head -n1 | cut -f2)
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
  if [ -n "${HADOOP_HOME:-}" ] && grep -qs 'fs.defaultFS' "${HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}/core-site.xml"; then
    ENV_HDFSCONF=1
  fi
  if have mongod || have mongosh || have mongo; then ENV_MONGO=1; fi
}
