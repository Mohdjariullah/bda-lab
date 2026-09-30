#!/usr/bin/env bash
# core/hadoop.sh - Hadoop / HDFS / YARN helpers with automatic repair

# hadoop_conf_dir : HADOOP_CONF_DIR when it is a real config dir, else etc/hadoop, else conf (old layout)
hadoop_conf_dir() {
  local d="${HADOOP_CONF_DIR:-}"
  if [ -n "$d" ] && { [ -f "$d/core-site.xml" ] || [ -f "$d/hadoop-env.sh" ]; }; then echo "$d"; return 0; fi
  for d in "$HADOOP_HOME/etc/hadoop" "$HADOOP_HOME/conf"; do
    [ -f "$d/hadoop-env.sh" ] || [ -f "$d/core-site.xml" ] && { echo "$d"; return 0; }
  done
  echo "$HADOOP_HOME/etc/hadoop"
}
hconf() { "$HADOOP_HOME/bin/hdfs" getconf -confKey "$1" 2>/dev/null | tail -n1; }
_strip_file_uri() { sed -E 's#^file:/*#/#'; }
hadoop_version() { "$HADOOP_HOME/bin/hadoop" version 2>/dev/null | head -n1 | awk '{print $2}'; }
hadoop_major_ge3() { version_ge "$(hadoop_version)" 3.0.0; }

# ---- hadoop-env.sh JAVA_HOME repair ---------------------------------------
fix_hadoop_env_java() {
  local f; f="$(hadoop_conf_dir)/hadoop-env.sh"
  [ -f "$f" ] || return 0
  local cur
  cur=$(grep -E '^[[:space:]]*export[[:space:]]+JAVA_HOME=' "$f" | tail -n1 \
        | sed -E 's/^[[:space:]]*export[[:space:]]+JAVA_HOME=//; s/^"//; s/"$//')
  cur=$(eval echo "$cur" 2>/dev/null)
  if [ -z "$cur" ]; then
    ok "hadoop-env.sh does not override JAVA_HOME; environment value is used ($JAVA_HOME)"
    return 0
  fi
  if [ -x "$cur/bin/java" ]; then
    ok "hadoop-env.sh JAVA_HOME: $cur"
    return 0
  fi
  fail "hadoop-env.sh exports an invalid JAVA_HOME: $cur"
  local bak="$f.bak.$(date +%Y%m%d_%H%M%S)"
  if cp "$f" "$bak" 2>/dev/null; then
    sed -i -E '/^[[:space:]]*export[[:space:]]+JAVA_HOME=/d' "$f"
    printf '\nexport JAVA_HOME=%s\n' "$JAVA_HOME" >> "$f"
    note_fix "hadoop-env.sh: export JAVA_HOME=$JAVA_HOME (backup: $bak)"
  else
    warn "Cannot edit $f (no write permission). Relying on the environment variable."
  fi
}

# ---- write a pseudo-distributed config when there is none ------------------
_xml() {   # _xml FILE prop=value ...
  local f=$1; shift
  {
    echo '<?xml version="1.0"?>'
    echo '<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>'
    echo '<!-- written by bigdata-lab-runner -->'
    echo '<configuration>'
    local kv
    for kv in "$@"; do
      printf '  <property><name>%s</name><value>%s</value></property>\n' "${kv%%=*}" "${kv#*=}"
    done
    echo '</configuration>'
  } > "$f"
}
write_pseudo_config() {
  local d; d=$(hadoop_conf_dir)
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local data="$HADOOP_DATA_DIR"
  mkdir -p "$data/tmp" "$data/namenode" "$data/datanode"
  local f
  for f in core-site.xml hdfs-site.xml; do [ -f "$d/$f" ] && cp "$d/$f" "$d/$f.bak.$ts"; done
  _xml "$d/core-site.xml" "fs.defaultFS=hdfs://localhost:9000" "hadoop.tmp.dir=$data/tmp"
  _xml "$d/hdfs-site.xml" "dfs.replication=1" \
       "dfs.namenode.name.dir=file://$data/namenode" \
       "dfs.datanode.data.dir=file://$data/datanode" \
       "dfs.permissions.enabled=false"
  [ -f "$d/mapred-site.xml" ] || _xml "$d/mapred-site.xml" "mapreduce.framework.name=local"
  note_fix "Wrote pseudo-distributed Hadoop config in $d (old files backed up as *.bak.$ts)"
  show "cat $d/core-site.xml"; cat "$d/core-site.xml"
}

# ---- Hadoop base environment ----------------------------------------------
ensure_hadoop() {
  ensure_java "8 11 17" || return 1
  ensure_tool hadoop || return 1
  local want_conf="${HADOOP_CONF_DIR:-}"
  export HADOOP_CONF_DIR="$(hadoop_conf_dir)"
  if [ -n "$want_conf" ] && [ "$want_conf" != "$HADOOP_CONF_DIR" ]; then
    fail "HADOOP_CONF_DIR pointed to a directory without a Hadoop configuration: $want_conf"
    note_fix "export HADOOP_CONF_DIR=$HADOOP_CONF_DIR"
  fi
  [ -d "$HADOOP_CONF_DIR" ] || die "Hadoop configuration directory missing: $HADOOP_CONF_DIR"
  export HADOOP_MAPRED_HOME="$HADOOP_HOME" HADOOP_COMMON_HOME="$HADOOP_HOME" HADOOP_HDFS_HOME="$HADOOP_HOME"
  export YARN_HOME="$HADOOP_HOME" HADOOP_COMMON_LIB_NATIVE_DIR="$HADOOP_HOME/lib/native"
  export HADOOP_OPTS="${HADOOP_OPTS:-} -Djava.library.path=$HADOOP_HOME/lib/native"

  check "Hadoop configuration ($HADOOP_CONF_DIR)"
  fix_hadoop_env_java

  # HDFS CLI layout: 'hdfs dfs' on normal builds, 'hadoop fs' if this hdfs script lacks it
  local o; o=$("$HADOOP_HOME/bin/hdfs" dfs -help 2>&1)
  if echo "$o" | grep -qi 'unknown command'; then
    warn "'hdfs dfs' is not supported by $HADOOP_HOME/bin/hdfs"
    HDFS_CLI=("$HADOOP_HOME/bin/hadoop" fs)
    fixmsg "Using 'hadoop fs' for file operations"
  else
    HDFS_CLI=("$HADOOP_HOME/bin/hdfs" dfs)
  fi
  ok "HDFS command: ${HDFS_CLI[*]}"

  local fs; fs=$(hconf fs.defaultFS)
  if [ -z "$fs" ] || [ "$fs" = "file:///" ]; then
    fail "fs.defaultFS is not configured (Hadoop would use the local filesystem, not HDFS)"
    if [ "$AUTO_WRITE_HADOOP_CONF" = 1 ]; then
      write_pseudo_config
      fs=$(hconf fs.defaultFS)
    else
      die "Set fs.defaultFS in $HADOOP_CONF_DIR/core-site.xml or set AUTO_WRITE_HADOOP_CONF=1"
    fi
  fi
  # the host in fs.defaultFS must resolve, or the NameNode cannot even bind (typical after a hostname change)
  local host; host=$(printf '%s' "$fs" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')
  if [ -n "$host" ] && [ "$host" != localhost ] && ! getent hosts "$host" >/dev/null 2>&1; then
    fail "fs.defaultFS uses the host name '$host', which does not resolve on this machine (hostname changed?)"
    if [ "$AUTO_WRITE_HADOOP_CONF" = 1 ]; then
      local d="$HADOOP_CONF_DIR" ts; ts=$(date +%Y%m%d_%H%M%S)
      cp "$d/core-site.xml" "$d/core-site.xml.bak.$ts" 2>/dev/null
      if sed -i -E "s#(hdfs://)$host([:/<])#\1localhost\2#g" "$d/core-site.xml" 2>/dev/null; then
        fs=$(hconf fs.defaultFS)
        note_fix "core-site.xml: fs.defaultFS host '$host' replaced by localhost (backup: core-site.xml.bak.$ts)"
      else
        warn "Cannot edit $d/core-site.xml (no write permission)"
      fi
    else
      die "Fix fs.defaultFS in $HADOOP_CONF_DIR/core-site.xml (use localhost) or set AUTO_WRITE_HADOOP_CONF=1"
    fi
  fi
  HDFS_URI=$fs
  ok "fs.defaultFS = $fs"
  note_ok "Hadoop $(hadoop_version): $HADOOP_HOME"
}

# hdfs_cmd ARGS : "hdfs dfs ARGS". If HDFS says "Permission denied" because the
# daemons were started by another user (the HDFS superuser), run the same
# command again as that user through HADOOP_USER_NAME (simple authentication).
hdfs_cmd() {
  run_as "hdfs dfs $*" "${HDFS_CLI[@]}" "$@" && return 0
  local rc=$?
  if [ -z "${HADOOP_USER_NAME:-}" ] && log_has 'Permission denied: user=' 40; then
    local su; su=$("${HDFS_CLI[@]}" -stat %u / 2>/dev/null | tail -n1)
    if [ -n "$su" ] && [ "$su" != "$(id -un)" ]; then
      fail "HDFS refused the operation: $(id -un) is not the HDFS superuser ($su started the NameNode)"
      export HADOOP_USER_NAME="$su"
      note_fix "export HADOOP_USER_NAME=$su  (act as the HDFS superuser, simple authentication)"
      run_as "hdfs dfs $*" "${HDFS_CLI[@]}" "$@"; return $?
    fi
  fi
  return "$rc"
}
hdfs_exists() { "${HDFS_CLI[@]}" -test -e "$1" 2>/dev/null; }
hdfs_rm_if_exists() {
  if hdfs_exists "$1"; then
    warn "Output directory already exists: $1"
    fixmsg "Deleting the old output so the job can run again"
    hdfs_cmd -rm -r -skipTrash "$1"
  fi
}

# ---- SSH -------------------------------------------------------------------
_ssh_ok() { timeout 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 localhost true >/dev/null 2>&1; }
ensure_ssh_localhost() {
  check "Passwordless SSH to localhost (used by start-dfs.sh)"
  if run_t 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 localhost true; then
    note_ok "SSH to localhost works"
    return 0
  fi
  warn "Passwordless SSH to localhost is not configured"
  if ! [ -x /usr/sbin/sshd ] && ! have sshd; then
    fixmsg "Installing openssh-server"
    ensure_sudo && run sudo apt-get install -y openssh-server
  fi
  if have systemctl; then
    if ! systemctl is-active --quiet ssh && ! systemctl is-active --quiet sshd; then
      fixmsg "Starting the SSH service"
      ensure_sudo && { run sudo systemctl start ssh || run sudo systemctl start sshd; }
    fi
  fi
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    fixmsg "Generating an SSH key"
    run ssh-keygen -t rsa -P "" -f "$HOME/.ssh/id_rsa"
  fi
  touch "$HOME/.ssh/authorized_keys"
  if ! grep -qsF "$(cut -d' ' -f2 "$HOME/.ssh/id_rsa.pub")" "$HOME/.ssh/authorized_keys"; then
    fixmsg "Adding the key to authorized_keys"
    cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
  fi
  chmod 600 "$HOME/.ssh/authorized_keys"
  ssh-keyscan -H localhost >> "$HOME/.ssh/known_hosts" 2>/dev/null
  if run_t 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=no localhost true; then
    note_fix "Passwordless SSH to localhost configured"
    return 0
  fi
  note_warn "SSH still fails. Daemons will be started directly (no SSH needed)."
  return 1
}

# ---- HDFS daemons ----------------------------------------------------------
hproc_running() {   # NameNode | DataNode | SecondaryNameNode | ResourceManager | NodeManager
  if have jps; then
    jps 2>/dev/null | awk '{print $2}' | grep -qx "$1"
  else
    pgrep -f "Dproc_$(echo "$1" | tr 'A-Z' 'a-z')" >/dev/null 2>&1
  fi
}
hdfs_alive() {
  timeout 60 "$HADOOP_HOME/bin/hdfs" dfsadmin -report 2>/dev/null \
    | grep -qE 'Live datanodes \([1-9]|Datanodes available: [1-9]'
}
_daemon() {   # _daemon start|stop namenode|datanode|...
  if hadoop_major_ge3; then
    run "$HADOOP_HOME/bin/hdfs" --daemon "$1" "$2"
  else
    run "$HADOOP_HOME/sbin/hadoop-daemon.sh" "$1" "$2"
  fi
}
namenode_needs_format() {
  NN_DIR=$(hconf dfs.namenode.name.dir | cut -d, -f1 | _strip_file_uri)
  [ -n "$NN_DIR" ] || NN_DIR="$(hconf hadoop.tmp.dir)/dfs/name"
  [ ! -f "$NN_DIR/current/VERSION" ]
}
start_hdfs_daemons() {   # $1 = 1 if SSH works
  if [ "$1" = 1 ] && [ -x "$HADOOP_HOME/sbin/start-dfs.sh" ]; then
    run "$HADOOP_HOME/sbin/start-dfs.sh" || true
  else
    hproc_running NameNode || _daemon start namenode
    hproc_running DataNode || _daemon start datanode
    hproc_running SecondaryNameNode || _daemon start secondarynamenode
  fi
}
wait_hdfs() {
  info "Waiting for NameNode and DataNode (up to ${SERVICE_TIMEOUT}s)..."
  local i=0
  while [ "$i" -lt "$SERVICE_TIMEOUT" ]; do
    if hproc_running NameNode && hproc_running DataNode && hdfs_alive; then return 0; fi
    sleep 3; i=$((i + 3))
  done
  return 1
}
hdfs_exit_safemode() {
  if "$HADOOP_HOME/bin/hdfs" dfsadmin -safemode get 2>/dev/null | grep -q ON; then
    info "NameNode is in safe mode, waiting for it to leave..."
    run_t 60 "$HADOOP_HOME/bin/hdfs" dfsadmin -safemode wait \
      || run "$HADOOP_HOME/bin/hdfs" dfsadmin -safemode leave
  fi
}
fix_datanode_clusterid() {
  local logdir="${HADOOP_LOG_DIR:-$HADOOP_HOME/logs}" log
  log=$(ls -t "$logdir"/hadoop-*-datanode-*.log 2>/dev/null | head -n1)
  [ -n "$log" ] || return 1
  if tail -n 300 "$log" | grep -q "Incompatible clusterIDs"; then
    fail "DataNode cannot start: Incompatible clusterIDs (NameNode was formatted again)"
    local d; d=$(hconf dfs.datanode.data.dir | cut -d, -f1 | _strip_file_uri)
    [ -n "$d" ] || d="$(hconf hadoop.tmp.dir)/dfs/data"
    [ -d "$d/current" ] || return 1
    fixmsg "Resetting DataNode storage $d/current (lab data only) and restarting the DataNode"
    _daemon stop datanode
    run rm -rf "$d/current"
    return 0
  fi
  warn "Last DataNode log lines ($log):"; tail -n 20 "$log"
  return 1
}

# running_hadoop_home : installation directory of the NameNode process that is running now
running_hadoop_home() {
  local args; args=$(ps -eo args= 2>/dev/null | grep -F 'Dproc_namenode' | grep -v grep | head -n1)
  [ -n "$args" ] || return 1
  local h
  h=$(printf '%s' "$args" | grep -oE '\-Dhadoop\.home\.dir=[^ ]+' | head -n1 | cut -d= -f2)
  [ -n "$h" ] || h=$(printf '%s' "$args" | grep -oE '\-Dhadoop\.log\.dir=[^ ]+' | head -n1 | cut -d= -f2 | sed 's#/logs/*$##')
  [ -n "$h" ] || h=$(printf '%s' "$args" | grep -oE '[^ :]+/share/hadoop/common' | head -n1 | sed 's#/share/hadoop/common$##')
  [ -n "$h" ] && readlink -f "$h"
}
# stop_hdfs_of HOME : stop the HDFS daemons of another Hadoop copy
stop_hdfs_of() {
  local h=$1 d
  for d in secondarynamenode datanode namenode; do
    if [ -x "$h/bin/hdfs" ] && "$h/bin/hdfs" --daemon stop "$d" >/dev/null 2>&1; then continue; fi
    [ -x "$h/sbin/hadoop-daemon.sh" ] && "$h/sbin/hadoop-daemon.sh" stop "$d" >/dev/null 2>&1
  done
  sleep 3
  pgrep -f 'Dproc_(namenode|datanode|secondarynamenode)' >/dev/null 2>&1 && pkill -f 'Dproc_(namenode|datanode|secondarynamenode)' 2>/dev/null
  sleep 2
  return 0
}

ensure_hdfs_running() {
  ensure_hadoop || return 1
  check "HDFS services"
  run jps || true
  if hproc_running NameNode && hproc_running DataNode && hdfs_alive; then
    note_ok "NameNode and DataNode already running"
    hdfs_exit_safemode
    return 0
  fi
  fail "HDFS is not fully running"
  [ "$AUTO_START_SERVICES" = 1 ] || die "AUTO_START_SERVICES=0, start HDFS manually"

  # a NameNode from ANOTHER Hadoop copy (different directory or config) does not answer this copy
  if hproc_running NameNode && ! hdfs_alive; then
    local other; other=$(running_hadoop_home)
    if [ -n "$other" ] && [ "$other" != "$(readlink -f "$HADOOP_HOME")" ]; then
      fail "A NameNode is running from another Hadoop copy: $other"
      note_fix "Stopping the daemons of $other so the selected copy ($HADOOP_HOME) can start"
      stop_hdfs_of "$other"
    fi
  fi

  local ssh_ok=1
  ensure_ssh_localhost || ssh_ok=0
  if namenode_needs_format; then
    warn "NameNode has never been formatted ($NN_DIR)"
    if ! mkdir -p "$NN_DIR" 2>/dev/null || [ ! -w "$NN_DIR" ]; then
      fail "The NameNode directory is not writable by $(id -un): $NN_DIR"
      [ "$AUTO_WRITE_HADOOP_CONF" = 1 ] || die "Change dfs.namenode.name.dir in hdfs-site.xml or set AUTO_WRITE_HADOOP_CONF=1"
      note_fix "Using $HADOOP_DATA_DIR for the HDFS name and data directories instead"
      write_pseudo_config
      namenode_needs_format || true
    fi
    fixmsg "Formatting the NameNode (first time only, nothing to lose yet)"
    run "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive || die "NameNode format failed"
  else
    ok "NameNode already formatted ($NN_DIR)"
    if [ ! -w "$NN_DIR/current" ]; then
      die "The HDFS name directory $NN_DIR belongs to another user ($(stat -c %U "$NN_DIR/current" 2>/dev/null)). Run the labs as that user, or start HDFS as that user first."
    fi
  fi
  fixmsg "Starting HDFS"
  start_hdfs_daemons "$ssh_ok"
  if ! wait_hdfs; then
    if fix_datanode_clusterid; then
      start_hdfs_daemons 0
      wait_hdfs || die "HDFS did not come up after the DataNode reset. Check $HADOOP_HOME/logs"
    else
      die "HDFS did not come up. Check $HADOOP_HOME/logs"
    fi
  fi
  run jps
  hdfs_exit_safemode
  note_fix "HDFS started (NameNode + DataNode running)"
}

# ---- YARN / MapReduce mode ------------------------------------------------
use_local_mr() {
  local d="$STATE_DIR/hadoop-conf-localmr"
  rm -rf "$d"; mkdir -p "$d"
  cp -r "$HADOOP_CONF_DIR"/. "$d"/
  _xml "$d/mapred-site.xml" "mapreduce.framework.name=local"
  export HADOOP_CONF_DIR="$d"
  MR_MODE=local
  note_fix "Jobs will run in local MapReduce mode (HADOOP_CONF_DIR=$d)"
}
# yarn_usable : the ResourceManager answers and at least one NodeManager is registered
yarn_usable() {
  timeout 45 "$HADOOP_HOME/bin/yarn" node -list 2>/dev/null | grep -qE 'Total Nodes:[[:space:]]*[1-9]'
}
_yarn_kill_apps() {   # kill applications still queued or running (after a timeout)
  local ids
  ids=$(timeout 45 "$HADOOP_HOME/bin/yarn" application -list -appStates SUBMITTED,ACCEPTED,RUNNING 2>/dev/null \
        | grep -oE 'application_[0-9]+_[0-9]+')
  local id
  for id in $ids; do
    warn "Killing YARN application $id"
    timeout 30 "$HADOOP_HOME/bin/yarn" application -kill "$id" >/dev/null 2>&1
  done
}
ensure_yarn_running() {
  if hproc_running ResourceManager && hproc_running NodeManager; then
    ok "ResourceManager and NodeManager processes are running"
    if yarn_usable; then ok "ResourceManager answers, a NodeManager is registered"; return 0; fi
    warn "YARN processes exist but the ResourceManager does not answer (or no NodeManager is registered)"
    return 1
  fi
  [ "$AUTO_START_SERVICES" = 1 ] || return 1
  fixmsg "Starting YARN"
  if _ssh_ok && [ -x "$HADOOP_HOME/sbin/start-yarn.sh" ]; then
    run "$HADOOP_HOME/sbin/start-yarn.sh" || true
  elif hadoop_major_ge3; then
    hproc_running ResourceManager || run "$HADOOP_HOME/bin/yarn" --daemon start resourcemanager
    hproc_running NodeManager || run "$HADOOP_HOME/bin/yarn" --daemon start nodemanager
  else
    run "$HADOOP_HOME/sbin/yarn-daemon.sh" start resourcemanager
    run "$HADOOP_HOME/sbin/yarn-daemon.sh" start nodemanager
  fi
  info "Waiting for the ResourceManager and a registered NodeManager (up to ${SERVICE_TIMEOUT}s)..."
  local i=0
  while [ "$i" -lt "$SERVICE_TIMEOUT" ]; do
    if ! hproc_running ResourceManager || ! hproc_running NodeManager; then
      sleep 5; i=$((i + 5))
      # a daemon that exits right after start-up is a real failure, do not wait the full time
      if [ "$i" -ge 20 ] && { ! hproc_running ResourceManager || ! hproc_running NodeManager; }; then
        fail "A YARN daemon stopped right after starting"
        local ylog; ylog=$(ls -t "${HADOOP_LOG_DIR:-$HADOOP_HOME/logs}"/*-resourcemanager-*.log 2>/dev/null | head -n1)
        [ -n "$ylog" ] && { warn "Last ResourceManager log lines ($ylog):"; grep -E 'ERROR|Exception' "$ylog" | tail -n 5; }
        return 1
      fi
      continue
    fi
    yarn_usable && return 0
    sleep 5; i=$((i + 5))
  done
  return 1
}
ensure_mapreduce() {
  local fw; fw=$(hconf mapreduce.framework.name); [ -n "$fw" ] || fw=local
  check "MapReduce framework: $fw"
  if [ "$fw" = yarn ]; then
    if ensure_yarn_running; then MR_MODE=yarn; note_ok "YARN is running, jobs run on YARN"; return 0; fi
    warn "YARN is not available"
    use_local_mr
  else
    MR_MODE=local
    ok "Jobs run in local mode (no YARN needed)"
  fi
}
# run_mr_job JAR CLASS INPUT OUTPUT : runs the job with a hard timeout;
# if it fails or hangs on YARN, retries in local mode.
: "${MR_JOB_TIMEOUT:=600}"
run_mr_job() {
  local jar=$1 cls=$2 in=$3 out=$4 rc
  hdfs_rm_if_exists "$out"
  run_as "hadoop jar $jar $cls $in $out" timeout --foreground -k 10 "$MR_JOB_TIMEOUT" \
         "$HADOOP_HOME/bin/hadoop" jar "$jar" "$cls" "$in" "$out"; rc=$?
  [ "$rc" -eq 0 ] && return 0
  if [ "${MR_MODE:-local}" = yarn ]; then
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      fail "The job did not finish on YARN within ${MR_JOB_TIMEOUT}s"
      _yarn_kill_apps
    else
      fail "Job failed on YARN"
    fi
    if log_has "MRAppMaster|Could not find or load main class"; then
      warn "YARN cannot find the MapReduce application master (mapreduce.application.classpath not set)"
    fi
    use_local_mr
    hdfs_rm_if_exists "$out"
    info "Re-running the job in local mode"
    run_as "hadoop jar $jar $cls $in $out" timeout --foreground -k 10 "$MR_JOB_TIMEOUT" \
           "$HADOOP_HOME/bin/hadoop" jar "$jar" "$cls" "$in" "$out"
    return $?
  fi
  return "$rc"
}
hadoop_classpath() { "$HADOOP_HOME/bin/hadoop" classpath 2>/dev/null; }

# hdfs_put SRC DEST : exact "hdfs dfs -put" first. If the file is already there
# (left by a previous run) delete it and put again.
hdfs_put() {
  hdfs_cmd -put "$1" "$2" && return 0
  if log_has 'File exists|already exists' 20; then
    local target="$2"
    case "$target" in */) target="$2$(basename "$1")" ;; esac
    hdfs_exists "$target" || target="$2/$(basename "$1")"
    warn "The file already exists in HDFS (left from a previous run)"
    fixmsg "Deleting the old copy and running the put again"
    hdfs_cmd -rm -skipTrash "$target"
    hdfs_cmd -put "$1" "$2"; return $?
  fi
  return 1
}
# hdfs_cp SRC DEST : same idea for "hdfs dfs -cp"
hdfs_cp() {
  hdfs_cmd -cp "$1" "$2" && return 0
  if log_has 'File exists|already exists' 20; then
    warn "The target already exists in HDFS (left from a previous run)"
    fixmsg "Deleting it and running the copy again"
    hdfs_cmd -rm -r -skipTrash "$2"
    hdfs_cmd -cp "$1" "$2"; return $?
  fi
  return 1
}
# hdfs_get SRC LOCAL : same idea for "hdfs dfs -get"
hdfs_get() {
  hdfs_cmd -get "$1" "$2" && return 0
  if log_has 'File exists|already exists' 20; then
    warn "The local file already exists"
    fixmsg "Deleting it and downloading again"
    rm -f "$2"
    hdfs_cmd -get "$1" "$2"; return $?
  fi
  return 1
}
