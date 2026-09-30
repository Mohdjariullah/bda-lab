#!/usr/bin/env bash
# core/diag/run.sh - full environment report. Only resolves paths; it does not
# start services, install packages or edit configuration.

_d_ok()   { ok "$*"; }
_d_bad()  { fail "$*"; DIAG_PROBLEMS=$((DIAG_PROBLEMS + 1)); }
_d_item() { if eval "$2" >/dev/null 2>&1; then _d_ok "$1"; else _d_bad "$1"; fi; }

lab_main() {
  DIAG_PROBLEMS=0
  local h v

  banner "BIG DATA ENVIRONMENT DIAGNOSTICS"

  echo; echo "${C_BOLD}OPERATING SYSTEM${C_RESET}"
  _d_ok "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)  ($(uname -m))"
  _d_item "Graphical session (needed for separate lab windows)" "has_display"
  if detect_terminal_emulator; then _d_ok "Terminal emulator: $TERM_EMULATOR"; else _d_bad "No terminal emulator found (labs run inline)"; fi

  echo; echo "${C_BOLD}JAVA${C_RESET}"
  local list; list=$(list_javas)
  if [ -n "$list" ]; then
    printf '%s\n' "$list" | awk -F'\t' '{printf "  [✓] Java %-3s %s\n", $1, $2}'
    if [ -n "${JAVA_HOME:-}" ]; then
      if [ -x "$JAVA_HOME/bin/javac" ]; then _d_ok "JAVA_HOME = $JAVA_HOME"; else _d_bad "JAVA_HOME invalid: $JAVA_HOME"; fi
    else warn "JAVA_HOME not set in this shell (the runner sets it per lab)"; fi
  else
    _d_bad "No JDK found (java + javac)"
  fi

  echo; echo "${C_BOLD}PYTHON${C_RESET}"
  _d_item "python3 ($(python3 --version 2>&1))" "have python3"
  _d_item "pip" "python3 -m pip --version"
  local m
  for m in numpy pandas matplotlib seaborn pyspark kafka; do
    _d_item "module $m" "python3 -c 'import $m'"
  done

  echo; echo "${C_BOLD}HADOOP${C_RESET}"
  locate_home hadoop; h=$LOCATED_HOME
  if [ -n "$h" ]; then
    export HADOOP_HOME=$h
    _d_ok "HADOOP_HOME = $h  (source: $LOCATE_SOURCE)"
    [ -n "$LOCATE_CANDIDATES" ] && [ "$(printf '%s\n' "$LOCATE_CANDIDATES" | wc -l)" -gt 1 ] && { warn "Several copies:"; printf '%s\n' "$LOCATE_CANDIDATES" | sed 's/^/      /'; }
    local p; p=$(command -v hadoop 2>/dev/null)
    if [ -n "$p" ] && [ "$(readlink -f "$p")" != "$(readlink -f "$h/bin/hadoop")" ]; then _d_bad "hadoop on PATH is a different copy: $p"; fi
    _d_item "hadoop executable ($(hadoop_version 2>/dev/null))" "[ -x '$h/bin/hadoop' ]"
    _d_item "hdfs executable" "[ -x '$h/bin/hdfs' ]"
    _d_item "hadoop-env.sh present" "[ -f '$h/etc/hadoop/hadoop-env.sh' ]"
    if [ -x "$h/bin/hdfs" ] && [ -n "${JAVA_HOME:-}" ] || [ -x "$h/bin/hdfs" ]; then
      v=$(hconf fs.defaultFS)
      if [ -n "$v" ] && [ "$v" != "file:///" ]; then _d_ok "fs.defaultFS = $v"; else _d_bad "fs.defaultFS not set (local filesystem mode)"; fi
      v=$(hconf mapreduce.framework.name); _d_ok "mapreduce.framework.name = ${v:-local (default)}"
    fi
    _d_item "hadoop-common jar" "ls '$h'/share/hadoop/common/hadoop-common-*.jar"
    _d_item "MapReduce libraries" "ls '$h'/share/hadoop/mapreduce/hadoop-mapreduce-client-core-*.jar"
    echo; echo "${C_BOLD}HDFS / YARN PROCESSES${C_RESET}"
    local pr
    for pr in NameNode DataNode SecondaryNameNode ResourceManager NodeManager; do
      if hproc_running "$pr"; then _d_ok "$pr running"; else warn "$pr not running (the lab starts it when needed)"; fi
    done
  else
    _d_bad "Hadoop not found"
  fi

  echo; echo "${C_BOLD}SSH${C_RESET}"
  _d_item "sshd installed" "[ -x /usr/sbin/sshd ] || have sshd"
  _d_item "passwordless ssh localhost" "_ssh_ok"

  echo; echo "${C_BOLD}PIG${C_RESET}"
  locate_home pig; h=$LOCATED_HOME; if [ -n "$h" ]; then _d_ok "PIG_HOME = $h ($(version_from_path "$h"))"; _d_item "pig core jar" "ls '$h'/pig-*core*.jar"; else _d_bad "Pig not found"; fi

  echo; echo "${C_BOLD}MONGODB${C_RESET}"
  _d_item "shell (mongosh or mongo)" "have mongosh || have mongo"
  _d_item "server (mongod)" "have mongod || port_in_use 27017"
  if port_in_use 27017; then _d_ok "mongod listening on 27017"; else warn "mongod not running (the lab starts it)"; fi

  echo; echo "${C_BOLD}HIVE${C_RESET}"
  locate_home hive; h=$LOCATED_HOME; if [ -n "$h" ]; then _d_ok "HIVE_HOME = $h ($(version_from_path "$h"))"; _d_item "hive-exec jar" "ls '$h'/lib/hive-exec-*.jar"; _d_item "schematool" "[ -x '$h/bin/schematool' ]"; else _d_bad "Hive not found"; fi

  echo; echo "${C_BOLD}SPARK${C_RESET}"
  locate_home spark; h=$LOCATED_HOME
  if [ -n "$h" ]; then _d_ok "SPARK_HOME = $h"; _d_item "spark-submit" "[ -x '$h/bin/spark-submit' ]"
  elif python3 -c 'import pyspark' 2>/dev/null; then _d_ok "pyspark Python package (no separate SPARK_HOME)"
  else _d_bad "Spark not found"; fi

  echo; echo "${C_BOLD}KAFKA${C_RESET}"
  locate_home kafka; h=$LOCATED_HOME
  if [ -n "$h" ]; then _d_ok "KAFKA_HOME = $h ($(version_from_path "$h"))"; else _d_bad "Kafka not found"; fi
  if port_in_use "$KAFKA_PORT"; then _d_ok "broker listening on $KAFKA_PORT"; else warn "no broker on $KAFKA_PORT (the lab starts it)"; fi

  echo; echo "${C_BOLD}PORTS${C_RESET}"
  local port
  for port in 9000 9870 8088 27017 2181 "$KAFKA_PORT" "$LAB9_STREAM_PORT" 4040; do
    if port_in_use "$port"; then
      local pc; pc=$(pid_cmd "$(port_pid "$port")" | cut -c1-70)
      echo "  [→] $port in use${pc:+ by: $pc}"
    else
      echo "  [ ] $port free"
    fi
  done

  echo; echo "${C_BOLD}PERMISSIONS${C_RESET}"
  _d_item "lab work directory writable ($LAB_WORKDIR_BASE)" "mkdir -p '$LAB_WORKDIR_BASE' && [ -w '$LAB_WORKDIR_BASE' ]"
  if sudo -n true 2>/dev/null; then _d_ok "sudo already authenticated"; else warn "sudo will ask for your password when a lab needs it"; fi
  local mp free
  for mp in "$HOME" /tmp; do
    free=$(df -Pk "$mp" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024}')
    if [ -n "$free" ]; then
      if [ "$free" -lt 2048 ]; then _d_bad "Free disk space on $mp: ${free} MB (Hadoop and Spark need room for logs and temp files)"; else _d_ok "Free disk space on $mp: ${free} MB"; fi
    fi
  done
  free=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
  [ -n "$free" ] && { if [ "$free" -lt 3500 ]; then warn "RAM: ${free} MB (Hive and Spark may be slow; the runner uses small heaps)"; else _d_ok "RAM: ${free} MB"; fi; }

  echo
  if [ "$DIAG_PROBLEMS" -eq 0 ]; then
    note_ok "RESULT: READY FOR LAB EXECUTION"
  else
    note_warn "RESULT: $DIAG_PROBLEMS item(s) need attention. The labs try to fix what they can automatically."
  fi
  return 0
}
