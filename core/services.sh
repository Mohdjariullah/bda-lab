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
kill_pid() { kill "$1" 2>/dev/null; sleep 2; kill -0 "$1" 2>/dev/null && kill -9 "$1" 2>/dev/null; return 0; }

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
  show "nohup $* > $log 2>&1 &"
  _logline "$ nohup $* > $log 2>&1 &"
  nohup "$@" > "$log" 2>&1 &
  local pid=$!
  echo "$pid" > "$STATE_DIR/$name.pid"
  info "$name started (pid $pid), log: $log"
}

# ---- MongoDB ---------------------------------------------------------------
ensure_mongodb() {
  check "MongoDB shell"
  MONGO_SHELL=""
  if have mongosh; then MONGO_SHELL=mongosh; elif have mongo; then MONGO_SHELL=mongo; fi
  if [ -n "$MONGO_SHELL" ]; then
    run_sh "$MONGO_SHELL --version 2>&1 | head -n 3"
  else
    fail "No MongoDB shell found (mongosh / mongo)"
  fi

  check "MongoDB server (port 27017)"
  if port_in_use 27017; then
    note_ok "mongod reachable on 27017 (reusing the running server)"
  else
    fail "MongoDB server is not running"
    [ "$AUTO_START_SERVICES" = 1 ] || return 1
    if have systemctl && systemctl list-unit-files 2>/dev/null | grep -qE '^mongod\.service'; then
      fixmsg "Starting mongod through systemd"
      ensure_sudo && run sudo systemctl start mongod
    elif have systemctl && systemctl list-unit-files 2>/dev/null | grep -qE '^mongodb\.service'; then
      fixmsg "Starting mongodb through systemd"
      ensure_sudo && run sudo systemctl start mongodb
    elif have mongod; then
      local d="$LAB_WORK/mongodata"; mkdir -p "$d"
      fixmsg "Starting a local mongod (dbpath $d)"
      # use a private socket dir: /tmp/mongodb-27017.sock may be owned by another user and block the start
      run mongod --fork --dbpath "$d" --logpath "$d/mongod.log" --bind_ip 127.0.0.1 --port 27017 --unixSocketPrefix "$d" \
        || { warn "mongod did not start. Last log lines:"; tail -n 8 "$d/mongod.log" 2>/dev/null | cut -c1-200; }
    else
      fail "mongod is not installed"
      fixmsg "Trying to install it with apt (mongodb-org from the MongoDB repository, or the distribution package)"
      if ensure_sudo; then
        if apt-cache policy mongodb-org 2>/dev/null | grep -q Candidate: && ! apt-cache policy mongodb-org 2>/dev/null | grep -q 'Candidate: (none)'; then
          run sudo apt-get install -y mongodb-org && { run sudo systemctl start mongod || true; }
        elif apt-cache policy mongodb 2>/dev/null | grep -q Candidate: && ! apt-cache policy mongodb 2>/dev/null | grep -q 'Candidate: (none)'; then
          run sudo apt-get install -y mongodb && { run sudo systemctl start mongodb || true; }
        else
          fail "No MongoDB package is available from apt on this system"
          info "Install MongoDB Community Server first: https://www.mongodb.com/docs/manual/administration/install-on-linux/"
          info "Then run this lab again. The runner will detect the running server or start it."
          return 1
        fi
      fi
    fi
    wait_for_port 27017 60 || die "MongoDB did not start. Check the mongod log."
    note_fix "MongoDB server started"
  fi

  if [ -z "$MONGO_SHELL" ]; then
    fixmsg "Trying to install a MongoDB shell"
    ensure_sudo && { run sudo apt-get install -y mongodb-mongosh || run sudo apt-get install -y mongodb-clients; }
    if have mongosh; then MONGO_SHELL=mongosh; elif have mongo; then MONGO_SHELL=mongo; else die "No MongoDB shell available"; fi
  fi
  note_ok "MongoDB ready (shell: $MONGO_SHELL)"
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
  bg_start kafka "$LAB_WORK/kafka-server.log" "$KAFKA_HOME/bin/kafka-server-start.sh" "$KAFKA_CFG"
  info "Waiting for the broker on port $KAFKA_PORT (up to ${SERVICE_TIMEOUT}s)..."
  wait_for_port "$KAFKA_PORT" "$SERVICE_TIMEOUT"
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

  check "Kafka broker on port $KAFKA_PORT"
  if port_in_use "$KAFKA_PORT"; then
    local pid cmd; pid=$(port_pid "$KAFKA_PORT"); cmd=$(pid_cmd "$pid")
    if [ -z "$pid" ] || echo "$cmd" | grep -qi kafka; then
      note_ok "Kafka broker already running${pid:+ (pid $pid)}. Reusing it."
      return 0
    fi
    die "Port $KAFKA_PORT is used by another program: $cmd"
  fi
  fail "No Kafka broker on port $KAFKA_PORT"
  [ "$AUTO_START_SERVICES" = 1 ] || return 1

  if [ "$KAFKA_MODE" = zookeeper ]; then
    check "ZooKeeper on port 2181"
    if port_in_use 2181; then
      ok "ZooKeeper already running"
    else
      fixmsg "Starting ZooKeeper"
      bg_start zookeeper "$LAB_WORK/zookeeper.log" "$KAFKA_HOME/bin/zookeeper-server-start.sh" "$KAFKA_HOME/config/zookeeper.properties"
      wait_for_port 2181 60 || die "ZooKeeper did not start. See $LAB_WORK/zookeeper.log"
      ok "ZooKeeper is up"
    fi
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

  fixmsg "Starting the Kafka broker"
  if ! _kafka_start_broker; then
    if grep -q "InconsistentClusterIdException" "$LAB_WORK/kafka-server.log" 2>/dev/null; then
      fail "Broker refused to start: cluster ID mismatch (old log directory from another ZooKeeper instance)"
      local ld; ld=$(kafka_prop "$KAFKA_CFG" log.dirs); ld=${ld:-/tmp/kafka-logs}
      fixmsg "Removing stale Kafka log directory $ld and retrying"
      run rm -rf "$ld"
      _kafka_start_broker || die "Kafka still not up. See $LAB_WORK/kafka-server.log"
    else
      warn "Last lines of the broker log:"; tail -n 15 "$LAB_WORK/kafka-server.log"
      die "Kafka broker did not start"
    fi
  fi
  note_fix "Kafka broker started on port $KAFKA_PORT"
}
