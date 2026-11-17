#!/usr/bin/env bash
# core/hadoop.sh - Hadoop / HDFS / YARN helpers with automatic repair

# hadoop_conf_dir : the runner's PRIVATE Hadoop configuration directory.
# The installation's own etc/hadoop is never used and never edited: it may be
# read-only (root-owned install), point to another host, another data
# directory or a YARN setup that does not work. That is where "environment not
# configured" errors come from. The private directory starts as a copy of
# etc/hadoop and gets the runner's core-site, hdfs-site, mapred-site and env.
hadoop_conf_dir() { echo "$STATE_DIR/hadoop-conf"; }

# build_hadoop_conf : create or refresh the private configuration
build_hadoop_conf() {
  local d src marker home
  d=$(hadoop_conf_dir); marker="$d/.built-for"
  home=$(readlink -f "$HADOOP_HOME")
  HADOOP_RUN_DIR="$LAB_WORKDIR_BASE/hadoop-run"; mkdir -p "$HADOOP_RUN_DIR/logs" "$HADOOP_RUN_DIR/pids"
  # the data directory of an earlier run that had to move (name dir owned by another user)
  [ -s "$STATE_DIR/hadoop-data-dir" ] && HADOOP_DATA_DIR=$(cat "$STATE_DIR/hadoop-data-dir")
  if [ "$(cat "$marker" 2>/dev/null)" != "v2|$home|$JAVA_HOME|$HADOOP_DATA_DIR" ]; then
    src="$HADOOP_HOME/etc/hadoop"; [ -d "$src" ] || src="$HADOOP_HOME/conf"
    wipe_dir "$d"; mkdir -p "$d"
    [ -d "$src" ] && cp -r "$src"/. "$d"/ 2>/dev/null
    chmod -R u+w "$d" 2>/dev/null
    rm -f "$d"/yarn-site.xml.bak* 2>/dev/null
    local data="$HADOOP_DATA_DIR"
    mkdir -p "$data/tmp" "$data/namenode" "$data/datanode"
    _xml "$d/core-site.xml" "fs.defaultFS=hdfs://localhost:9000" "hadoop.tmp.dir=$data/tmp"
    _xml "$d/hdfs-site.xml" "dfs.replication=1" \
         "dfs.namenode.name.dir=file://$data/namenode" \
         "dfs.datanode.data.dir=file://$data/datanode" \
         "dfs.permissions.enabled=false"
    # staging dir: the default is /tmp/hadoop/mapred/staging, shared by every user of
    # the PC. If another user ran a job first, it belongs to them and jobs fail (ENOENT).
    _xml "$d/mapred-site.xml" "mapreduce.framework.name=local" \
         "mapreduce.jobtracker.staging.root.dir=$data/tmp/mapred/staging"
    _xml "$d/yarn-site.xml"
    # hadoop-env.sh: drop every JAVA_HOME / log / pid line of the PC, add the runner's
    touch "$d/hadoop-env.sh"
    sed -i -E '/^[[:space:]]*export[[:space:]]+(JAVA_HOME|HADOOP_LOG_DIR|HADOOP_PID_DIR|HADOOP_CONF_DIR|HADOOP_HOME|HADOOP_CLASSPATH|HADOOP_OPTS)=/d' "$d/hadoop-env.sh"
    {
      echo "# added by bigdata-lab-runner"
      echo "export JAVA_HOME=$JAVA_HOME"
      echo "export HADOOP_LOG_DIR=$HADOOP_RUN_DIR/logs"
      echo "export HADOOP_PID_DIR=$HADOOP_RUN_DIR/pids"
    } >> "$d/hadoop-env.sh"
    printf '%s' "v2|$home|$JAVA_HOME|$HADOOP_DATA_DIR" > "$marker"
    info "Hadoop configuration for the labs written to $d (the files in $src are not changed)"
  fi
  export HADOOP_CONF_DIR="$d" HADOOP_LOG_DIR="$HADOOP_RUN_DIR/logs" HADOOP_PID_DIR="$HADOOP_RUN_DIR/pids"
}
hconf() { "$HADOOP_HOME/bin/hdfs" getconf -confKey "$1" 2>/dev/null | tail -n1; }
_strip_file_uri() { sed -E 's#^file:/*#/#'; }
hadoop_version() { "$HADOOP_HOME/bin/hadoop" version 2>/dev/null | head -n1 | awk '{print $2}'; }
hadoop_major_ge3() { version_ge "$(hadoop_version)" 3.0.0; }

# ---- configuration files ---------------------------------------------------
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
# move_hdfs_data DIR : use another data directory from now on (and remember it)
move_hdfs_data() {
  HADOOP_DATA_DIR=$1
  printf '%s\n' "$HADOOP_DATA_DIR" > "$STATE_DIR/hadoop-data-dir"
  rm -f "$(hadoop_conf_dir)/.built-for"
  build_hadoop_conf
}

# ---- Hadoop base environment ----------------------------------------------
ensure_hadoop() {
  ensure_java "8 11 17" || return 1
  ensure_tool hadoop || return 1
  build_hadoop_conf
  export HADOOP_MAPRED_HOME="$HADOOP_HOME" HADOOP_COMMON_HOME="$HADOOP_HOME" HADOOP_HDFS_HOME="$HADOOP_HOME"
  export YARN_HOME="$HADOOP_HOME" HADOOP_COMMON_LIB_NATIVE_DIR="$HADOOP_HOME/lib/native"
  if [ "$(id -u)" -eq 0 ]; then
    # Hadoop 3 refuses to start its daemons as root unless the user is declared
    export HDFS_NAMENODE_USER=root HDFS_DATANODE_USER=root HDFS_SECONDARYNAMENODE_USER=root
    export YARN_RESOURCEMANAGER_USER=root YARN_NODEMANAGER_USER=root
  fi
  export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"

  # HDFS CLI layout: 'hdfs dfs' on normal builds, 'hadoop fs' if this hdfs script lacks it
  local o; o=$("$HADOOP_HOME/bin/hdfs" dfs -help 2>&1)
  if echo "$o" | grep -qi 'unknown command'; then
    HDFS_CLI=("$HADOOP_HOME/bin/hadoop" fs)
  else
    HDFS_CLI=("$HADOOP_HOME/bin/hdfs" dfs)
  fi
  HDFS_URI=$(hconf fs.defaultFS)
  ok "fs.defaultFS = $HDFS_URI"
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
  # start-dfs.sh needs an SSH server. Without one the daemons are started
  # directly with "hdfs --daemon start", which gives the same result, so
  # nothing is installed here.
  if ! have ssh || ! port_in_use 22; then
    info "No SSH server on this machine. The HDFS daemons will be started directly (same result as start-dfs.sh)."
    return 1
  fi
  if _ssh_ok; then
    note_ok "SSH to localhost works"
    return 0
  fi
  warn "Passwordless SSH to localhost is not configured"
  mkdir -p "$REAL_HOME/.ssh"; chmod 700 "$REAL_HOME/.ssh"
  if [ ! -f "$REAL_HOME/.ssh/id_rsa" ]; then
    fixmsg "Generating an SSH key"
    run ssh-keygen -q -t rsa -P "" -f "$REAL_HOME/.ssh/id_rsa"
  fi
  touch "$REAL_HOME/.ssh/authorized_keys"
  if ! grep -qsF "$(cut -d' ' -f2 "$REAL_HOME/.ssh/id_rsa.pub")" "$REAL_HOME/.ssh/authorized_keys"; then
    fixmsg "Adding the key to authorized_keys"
    cat "$REAL_HOME/.ssh/id_rsa.pub" >> "$REAL_HOME/.ssh/authorized_keys"
  fi
  chmod 600 "$REAL_HOME/.ssh/authorized_keys"
  if _ssh_ok; then
    note_fix "Passwordless SSH to localhost configured"
    return 0
  fi
  info "SSH to localhost is not usable. The HDFS daemons will be started directly (same result as start-dfs.sh)."
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
  # "detached": the daemon must survive the closing of the lab window
  if hadoop_major_ge3; then
    run_as "hdfs --daemon $1 $2" detached "$HADOOP_HOME/bin/hdfs" --daemon "$1" "$2"
  else
    run_as "hadoop-daemon.sh $1 $2" detached "$HADOOP_HOME/sbin/hadoop-daemon.sh" "$1" "$2"
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
    # a NameNode that is gone 15 s after its start has failed (bad data dir, port in use):
    # waiting longer does not help, the caller repairs it
    if [ "$i" -ge 15 ] && ! pgrep -f 'Dproc_namenode' >/dev/null 2>&1; then
      warn "The NameNode stopped right after starting"
      return 1
    fi
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
    wipe_dir "$d/current"
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

# _hadoop_daemons : "PID ARGS" of every HDFS/YARN daemon process on this PC
_hadoop_daemons() {
  ps -eo pid=,args= | grep -E 'Dproc_(namenode|datanode|secondarynamenode|resourcemanager|nodemanager)' | grep -v grep
}
# stop_hadoop_daemons all|foreign : stop the daemons that block the lab.
#   foreign = started from another Hadoop copy; all = every one (when the
#   running HDFS does not answer the lab's configuration)
stop_hadoop_daemons() {
  local which=$1 mine pid args stuck=0
  mine=$(readlink -f "$HADOOP_HOME")
  while read -r pid args; do
    [ -n "$pid" ] || continue
    if [ "$which" = foreign ]; then
      case "$args" in *"$mine/"*|*"$HADOOP_HOME/"*) continue ;; esac
      fail "A Hadoop daemon from another installation is running (pid $pid, user $(ps -o user= -p "$pid" 2>/dev/null))"
    else
      fail "A Hadoop daemon that does not answer the lab is running (pid $pid, user $(ps -o user= -p "$pid" 2>/dev/null))"
    fi
    stop_pid_any "$pid" "This Hadoop daemon" || stuck=1
  done < <(_hadoop_daemons)
  [ "$stuck" = 0 ] || die "Hadoop daemons of another user are still running and hold the HDFS ports. Restart the PC and run the lab again."
}

# _hdfs_reset : last resort when HDFS does not start with the data that is on
# disk (written by another Hadoop version, half formatted, damaged). Only the
# runner's own data directory is ever removed; it holds lab data only.
_hdfs_reset() {
  case "$NN_DIR" in "$HADOOP_DATA_DIR"/*) ;; *) return 1 ;; esac
  fail "HDFS does not start with the existing data in $HADOOP_DATA_DIR"
  note_fix "Removing the old HDFS data (lab data only), formatting the NameNode and starting again"
  local d
  for d in secondarynamenode datanode namenode; do _daemon stop "$d" >/dev/null 2>&1; done
  pkill -f "Dproc_(namenode|datanode|secondarynamenode).*$HADOOP_HOME/" 2>/dev/null; sleep 2
  for d in namenode datanode tmp; do
    wipe_dir "$HADOOP_DATA_DIR/$d"; mkdir -p "$HADOOP_DATA_DIR/$d"
  done
  run "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive || return 1
  start_hdfs_daemons 0
  wait_hdfs
}

ensure_hdfs_running() {
  ensure_hadoop || return 1
  check "HDFS services"
  stop_hadoop_daemons foreign
  run jps || true
  if hproc_running NameNode && hproc_running DataNode && hdfs_alive; then
    note_ok "NameNode and DataNode already running"
    hdfs_exit_safemode
    return 0
  fi
  info "HDFS is not running yet"
  [ "$AUTO_START_SERVICES" = 1 ] || die "AUTO_START_SERVICES=0, start HDFS manually"

  # daemons of this same copy that were started with the PC's own configuration
  # (another port, another data directory) do not answer the lab's configuration
  if [ -n "$(_hadoop_daemons)" ] && ! hdfs_alive; then
    stop_hadoop_daemons all
  fi

  local ssh_ok=1
  ensure_ssh_localhost || ssh_ok=0
  if namenode_needs_format; then
    warn "NameNode has never been formatted ($NN_DIR)"
    if ! mkdir -p "$NN_DIR" 2>/dev/null || [ ! -w "$NN_DIR" ]; then
      fail "The NameNode directory is not writable by $(id -un): $NN_DIR"
      note_fix "Using a new HDFS data directory for this user: $REAL_HOME/hadoopdata_$(id -un)"
      move_hdfs_data "$REAL_HOME/hadoopdata_$(id -un)"
      namenode_needs_format || true
    fi
    fixmsg "Formatting the NameNode (first time only, nothing to lose yet)"
    run "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive || die "NameNode format failed"
  else
    ok "NameNode already formatted ($NN_DIR)"
    if [ ! -w "$NN_DIR/current" ]; then
      fail "The HDFS name directory $NN_DIR belongs to another user ($(stat -c %U "$NN_DIR/current" 2>/dev/null))"
      note_fix "Using a new HDFS data directory for this user: $REAL_HOME/hadoopdata_$(id -un)"
      move_hdfs_data "$REAL_HOME/hadoopdata_$(id -un)"
      namenode_needs_format && { run "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive || die "NameNode format failed"; }
    fi
  fi
  fixmsg "Starting HDFS"
  start_hdfs_daemons "$ssh_ok"
  local up=0
  wait_hdfs && up=1
  if [ "$up" = 0 ] && [ "$ssh_ok" = 1 ]; then
    warn "start-dfs.sh did not bring HDFS up. Starting the daemons directly."
    start_hdfs_daemons 0
    wait_hdfs && up=1
  fi
  if [ "$up" = 0 ]; then
    if fix_datanode_clusterid; then
      start_hdfs_daemons 0
      wait_hdfs || _hdfs_reset || die "HDFS did not come up. Check $HADOOP_RUN_DIR/logs"
    else
      _hdfs_reset || die "HDFS did not come up. Check $HADOOP_RUN_DIR/logs"
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
  _xml "$d/mapred-site.xml" "mapreduce.framework.name=local" \
       "mapreduce.jobtracker.staging.root.dir=$HADOOP_DATA_DIR/tmp/mapred/staging"
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
    hproc_running ResourceManager || run_as "yarn --daemon start resourcemanager" detached "$HADOOP_HOME/bin/yarn" --daemon start resourcemanager
    hproc_running NodeManager || run_as "yarn --daemon start nodemanager" detached "$HADOOP_HOME/bin/yarn" --daemon start nodemanager
  else
    run_as "yarn-daemon.sh start resourcemanager" detached "$HADOOP_HOME/sbin/yarn-daemon.sh" start resourcemanager
    run_as "yarn-daemon.sh start nodemanager" detached "$HADOOP_HOME/sbin/yarn-daemon.sh" start nodemanager
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
