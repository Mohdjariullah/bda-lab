#!/usr/bin/env bash
# core/services.sh - ports, background daemons, MongoDB, ZooKeeper, Kafka

# ---- ports -----------------------------------------------------------------
port_in_use() {
  if have ss; then
    ss -ltn 2>/dev/null | awk 'NR>1 {print $4}' | grep -qE "[:.]$1$"
  elif have netstat; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1$"
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
  fi
}
port_pid() {   # pid of the process listening on a port (empty if unknown)
  local pid=""
  if have ss; then
    pid=$(ss -ltnp 2>/dev/null | grep -E "[:.]$1 " | grep -oE 'pid=[0-9]+' | head -n1 | cut -d= -f2)
  fi
  if [ -z "$pid" ] && have lsof; then pid=$(lsof -ti "tcp:$1" -sTCP:LISTEN 2>/dev/null | head -n1); fi
  if [ -z "$pid" ] && have fuser; then pid=$(fuser "$1/tcp" 2>/dev/null | awk '{print $1}'); fi
  echo "$pid"
}
pid_cmd() { ps -o args= -p "$1" 2>/dev/null; }
wait_for_port() {   # wait_for_port PORT [SECONDS]
  local p=$1 t=${2:-$SERVICE_TIMEOUT} i=0
  while [ "$i" -lt "$t" ]; do
    port_in_use "$p" && return 0
    sleep 2; i=$((i + 2))
  done
  return 1
}
# kill_pid PID : stop a process and wait until it is really gone (TERM, then KILL)
kill_pid() {
  local i
  kill "$1" 2>/dev/null
  for i in 1 2 3 4 5 6; do [ -d "/proc/$1" ] || return 0; sleep 0.5; done
  kill -9 "$1" 2>/dev/null
  for i in 1 2 3 4 5 6; do [ -d "/proc/$1" ] || return 0; sleep 0.5; done
  return 0
}

# stop_pid_any PID WHAT : stop a process that blocks a lab. A process of this
# user is simply stopped. A process of ANOTHER user needs administrator rights:
# the password is asked right here in the terminal (plain sudo, nothing stored).
# Returns 1 when the process is still running afterwards.
stop_pid_any() {
  local pid=$1 what=$2 owner
  owner=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
  [ -n "$owner" ] || return 0
  if [ "$owner" = "$(id -un)" ] || [ "$(id -u)" -eq 0 ]; then
    note_fix "Stopping it (pid $pid)"
    kill_pid "$pid"
  else
    # asked once: after a refusal the other processes are not tried again
    [ -z "${SUDO_REFUSED:-}" ] || return 1
    if ! have sudo; then fail "sudo is not installed on this PC"; SUDO_REFUSED=1; return 1; fi
    progress "[!] $what belongs to the user '$owner'. Type your password in the lab window to stop it."
    _logline "[WARN] $what belongs to the user '$owner': asking for the password (sudo)"
    # plain echo: these lines must be visible in the lab window in every output mode
    echo
    echo "${C_BOLD}$what (pid $pid) was started by the user '$owner' and blocks this lab.${C_RESET}"
    echo "${C_BOLD}Administrator rights are needed to stop it.${C_RESET}"
    echo "${C_BOLD}Type your Linux password and press ENTER (the letters do not show).${C_RESET}"
    if sudo -p "[sudo] password for %u: " kill "$pid"; then
      local i; for i in 1 2 3 4 5 6 7 8; do [ -d "/proc/$pid" ] || break; sleep 0.5; done
      [ -d "/proc/$pid" ] && sudo kill -9 "$pid" 2>/dev/null
      sleep 1
      [ -d "/proc/$pid" ] || note_fix "Stopped (pid $pid)"
    else
      SUDO_REFUSED=1
      fail "The password was not accepted, or this account is not allowed to use sudo"
    fi
  fi
  [ -d "/proc/$pid" ] && return 1
  return 0
}

# free_port PORT NAME_PATTERN : if a stale helper of ours holds the port, kill it.
# Returns 1 if the port is used by something else.
free_port() {
  local port=$1 pat=$2 pid cmd
  port_in_use "$port" || return 0
  pid=$(port_pid "$port")
  cmd=$(pid_cmd "$pid")
  if [ -n "$pid" ] && echo "$cmd" | grep -qE "$pat"; then
    warn "Port $port is held by a previous run (pid $pid)"
    fixmsg "Stopping stale process $pid"
    kill_pid "$pid"; sleep 1
    port_in_use "$port" && return 1
    return 0
  fi
  fail "Port $port is already in use by: ${cmd:-unknown process}"
  return 1
}

# bg_start NAME LOGFILE CMD... : start a daemon with nohup, remember its pid
bg_start() {
  local name=$1 log=$2; shift 2
  # BG_LABEL: the command as it is typed by hand (the runner's own log file and
  # private configuration file are not part of what a student types)
  show "${BG_LABEL:-nohup $* > $log 2>&1 &}"
  nohup "$@" > "$log" 2>&1 &
  local pid=$!
  echo "$pid" > "$STATE_DIR/$name.pid"
  info "$name started (pid $pid), log: $log"
}

# ---- Kafka -----------------------------------------------------------------
kafka_prop() { grep -E "^$2=" "$1" 2>/dev/null | tail -n1 | cut -d= -f2- | cut -d, -f1; }

kafka_topics_args() {
  if version_ge "${KAFKA_VER:-0}" 2.2; then
    echo "--bootstrap-server localhost:$KAFKA_PORT"
  else
    echo "--zookeeper localhost:2181"
  fi
}

_kafka_start_broker() {
  mkdir -p "$LAB_WORKDIR_BASE/kafka-data"
  BG_LABEL="kafka-server-start.sh -daemon \$KAFKA_HOME/config/server.properties" \
    bg_start kafka "$LAB_WORKDIR_BASE/kafka-data/kafka-server.log" "$KAFKA_HOME/bin/kafka-server-start.sh" "$KAFKA_CFG"
  info "Waiting for the broker on port $KAFKA_PORT (up to ${SERVICE_TIMEOUT}s)..."
  local pid i=0; pid=$(cat "$STATE_DIR/kafka.pid" 2>/dev/null)
  while [ "$i" -lt "$SERVICE_TIMEOUT" ]; do
    port_in_use "$KAFKA_PORT" && return 0
    # the broker process is gone: it failed during start-up, no point in waiting longer
    [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && return 1
    sleep 2; i=$((i + 2))
  done
  return 1
}

ensure_kafka() {
  ensure_tool kafka || return 1
  KAFKA_VER=$(version_from_path "$KAFKA_HOME")
  [ -n "$KAFKA_VER" ] || KAFKA_VER=$(ls "$KAFKA_HOME"/libs/kafka_*.jar 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)
  info "Kafka version: ${KAFKA_VER:-unknown}"
  if version_ge "${KAFKA_VER:-0}" 4.0; then JAVA_NEED_JDK=0 ensure_java "17 21 11" || return 1; else JAVA_NEED_JDK=0 ensure_java "8 11 17" || return 1; fi

  # ZooKeeper or KRaft?
  KAFKA_MODE=kraft; KAFKA_CFG="$KAFKA_HOME/config/server.properties"
  if [ -f "$KAFKA_HOME/config/zookeeper.properties" ] && ! version_ge "${KAFKA_VER:-0}" 4.0; then
    KAFKA_MODE=zookeeper
  elif [ -f "$KAFKA_HOME/config/kraft/server.properties" ]; then
    KAFKA_CFG="$KAFKA_HOME/config/kraft/server.properties"
  fi
  info "Kafka mode: $KAFKA_MODE (config: $KAFKA_CFG)"

  # The broker and ZooKeeper get their own configuration and data directory.
  # /tmp/kafka-logs and /tmp/zookeeper may hold data of another Kafka version,
  # and "localhost" listeners avoid errors when the PC's host name does not resolve.
  if [ "$KAFKA_MODE" = zookeeper ]; then
    KAFKA_DATA="$LAB_WORKDIR_BASE/kafka-data"; mkdir -p "$KAFKA_DATA"
    grep -vE '^(log\.dirs|listeners|advertised\.listeners|zookeeper\.connect)=' "$KAFKA_CFG" > "$KAFKA_DATA/server.properties"
    printf 'log.dirs=%s\nlisteners=PLAINTEXT://localhost:%s\nzookeeper.connect=localhost:2181\n' \
      "$KAFKA_DATA/kafka-logs" "$KAFKA_PORT" >> "$KAFKA_DATA/server.properties"
    grep -vE '^dataDir=' "$KAFKA_HOME/config/zookeeper.properties" > "$KAFKA_DATA/zookeeper.properties"
    printf 'dataDir=%s\n' "$KAFKA_DATA/zookeeper" >> "$KAFKA_DATA/zookeeper.properties"
    KAFKA_CFG="$KAFKA_DATA/server.properties"; ZK_CFG="$KAFKA_DATA/zookeeper.properties"
  fi

  # kafka-run-class.sh writes its logs into the installation folder by default,
  # which fails when that folder belongs to root
  mkdir -p "$LAB_WORKDIR_BASE/kafka-data/logs"; export LOG_DIR="$LAB_WORKDIR_BASE/kafka-data/logs"

  check "Kafka broker on port $KAFKA_PORT"
  local pid cmd
  if port_in_use "$KAFKA_PORT"; then
    pid=$(port_pid "$KAFKA_PORT"); cmd=$(pid_cmd "$pid")
    case "$cmd" in
      *"$KAFKA_HOME/"*) note_ok "Kafka broker already running (pid $pid). Reusing it."; return 0 ;;
    esac
    if [ -z "$pid" ]; then
      # a listener of another user hides its process from "lsof"; find it by name
      pid=$(pgrep -f 'kafka\.Kafka' | head -n1); cmd=$(pid_cmd "$pid")
    fi
    if [ -n "$pid" ] && echo "$cmd" | grep -qi kafka; then
      fail "A Kafka broker from another installation is running on port $KAFKA_PORT (pid $pid)"
      stop_pid_any "$pid" "This Kafka broker"; sleep 2
      port_in_use "$KAFKA_PORT" && die "Port $KAFKA_PORT is still held by a Kafka broker of another user. Restart the PC and run the lab again."
    else
      die "Port $KAFKA_PORT is used by another program: $cmd"
    fi
  fi
  info "No Kafka broker on port $KAFKA_PORT yet"
  [ "$AUTO_START_SERVICES" = 1 ] || return 1

  if [ "$KAFKA_MODE" = zookeeper ]; then
    check "ZooKeeper on port 2181"
    if port_in_use 2181; then
      pid=$(port_pid 2181); cmd=$(pid_cmd "$pid")
      case "$cmd" in
        *"$KAFKA_HOME/"*) ok "ZooKeeper already running" ;;
        *)
          [ -n "$pid" ] || pid=$(pgrep -f 'QuorumPeerMain' | head -n1)
          if [ -n "$pid" ]; then
            fail "A ZooKeeper from another installation is running on port 2181 (pid $pid)"
            stop_pid_any "$pid" "This ZooKeeper"; sleep 2
          fi
          port_in_use 2181 && warn "Port 2181 is still in use. The broker will try to use that ZooKeeper." ;;
      esac
    fi
    port_in_use 2181 || _zookeeper_start || die "ZooKeeper did not start. See $LAB_WORKDIR_BASE/kafka-data/zookeeper.log"
  else
    local logdir; logdir=$(kafka_prop "$KAFKA_CFG" log.dirs); logdir=${logdir:-/tmp/kraft-combined-logs}
    if [ ! -f "$logdir/meta.properties" ]; then
      fixmsg "KRaft storage not formatted yet, formatting $logdir"
      local uuid; uuid=$("$KAFKA_HOME/bin/kafka-storage.sh" random-uuid 2>/dev/null)
      run "$KAFKA_HOME/bin/kafka-storage.sh" format -t "$uuid" -c "$KAFKA_CFG" \
        || run "$KAFKA_HOME/bin/kafka-storage.sh" format -t "$uuid" -c "$KAFKA_CFG" --standalone \
        || die "kafka-storage format failed"
    fi
  fi

  if ! _kafka_start_broker; then
    local try=0
    # the last broker was killed (window closed, power off): ZooKeeper still holds
    # its registration until the old session expires (18 s by default)
    while grep -q "NodeExistsException" "$LAB_WORKDIR_BASE/kafka-data/kafka-server.log" 2>/dev/null && [ "$try" -lt 3 ]; do
      try=$((try + 1))
      fail "Broker refused to start: ZooKeeper still holds the registration of the previous broker"
      note_fix "Waiting 20 s for ZooKeeper to drop it, then starting the broker again ($try/3)"
      sleep 20
      _kafka_start_broker && { note_ok "Kafka broker started on port $KAFKA_PORT"; return 0; }
    done
    if [ "$KAFKA_MODE" = zookeeper ]; then
      # anything else (cluster id mismatch, data of another version, damaged logs):
      # the data is lab data only, so start again from an empty directory
      fail "The Kafka broker does not start with the existing data in $KAFKA_DATA"
      note_fix "Removing the old Kafka and ZooKeeper data and starting both again"
      pkill -f "$KAFKA_HOME/.*kafka\.Kafka" 2>/dev/null; pkill -f "$KAFKA_HOME/.*QuorumPeerMain" 2>/dev/null; sleep 3
      wipe_dir "$KAFKA_DATA/kafka-logs" "$KAFKA_DATA/zookeeper"
      port_in_use 2181 || _zookeeper_start || die "ZooKeeper did not start. See $LAB_WORKDIR_BASE/kafka-data/zookeeper.log"
      _kafka_start_broker && { note_ok "Kafka broker started on port $KAFKA_PORT"; return 0; }
    fi
    warn "Last lines of the broker log:"; tail -n 15 "$LAB_WORKDIR_BASE/kafka-data/kafka-server.log"
    die "Kafka broker did not start"
  fi
  note_ok "Kafka broker started on port $KAFKA_PORT"
}

_zookeeper_start() {
  mkdir -p "$LAB_WORKDIR_BASE/kafka-data"
  BG_LABEL="zookeeper-server-start.sh -daemon \$KAFKA_HOME/config/zookeeper.properties" \
    bg_start zookeeper "$LAB_WORKDIR_BASE/kafka-data/zookeeper.log" "$KAFKA_HOME/bin/zookeeper-server-start.sh" "${ZK_CFG:-$KAFKA_HOME/config/zookeeper.properties}"
  wait_for_port 2181 60
}
