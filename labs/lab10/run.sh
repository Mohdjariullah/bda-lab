#!/usr/bin/env bash
# Lab 10 - Event Streaming using Apache Kafka (manual: producer.py + consumer.py)

_topic_reset() {   # delete the topic from a previous run so the consumer shows only this run's events
  local targs=$1 topic=$2
  if "$KAFKA_HOME/bin/kafka-topics.sh" --list $targs 2>/dev/null | grep -qx "$topic"; then
    info "Topic $topic exists from a previous run, deleting it first"
    run "$KAFKA_HOME/bin/kafka-topics.sh" --delete $targs --topic "$topic" || return 0
    local i=0
    while "$KAFKA_HOME/bin/kafka-topics.sh" --list $targs 2>/dev/null | grep -qx "$topic"; do
      i=$((i + 1)); [ "$i" -ge 15 ] && { warn "Topic still marked for deletion, continuing anyway"; break; }
      sleep 1
    done
  fi
}

lab_main() {
  lab_workdir lab10
  cp "$LAB_DIR/producer.py" "$LAB_DIR/consumer.py" .
  local topic="lab-events" targs

  step 1 "Start ZooKeeper and the Kafka server"
  ensure_kafka || die "Kafka is not available"
  if [ "$KAFKA_PORT" != 9092 ]; then
    note_warn "The manual programs use localhost:9092 but the broker is on port $KAFKA_PORT"
    sed -i "s/localhost:9092/localhost:$KAFKA_PORT/" producer.py consumer.py
  fi
  targs=$(kafka_topics_args)

  step 2 "Create the topic"
  _topic_reset "$targs" "$topic"
  run "$KAFKA_HOME/bin/kafka-topics.sh" --create --topic "$topic" $targs --partitions 1 --replication-factor 1 \
    || warn "Topic creation returned an error (it may already exist)"
  run "$KAFKA_HOME/bin/kafka-topics.sh" --describe --topic "$topic" $targs

  step 3 "Python Kafka client (kafka-python)"
  ensure_python || die "Python is not available"
  ensure_pymods kafka:kafka-python:python3-kafka || ensure_pymods kafka:kafka-python-ng \
    || die "kafka-python could not be installed (pip3 install kafka-python)"

  step 4 "Programs"
  show "cat producer.py"; cat producer.py
  show "cat consumer.py"; cat consumer.py

  step 5 "Start the consumer in the background (it listens until stopped)"
  show "python3 consumer.py > consumer.log &"
  python3 consumer.py > consumer.log 2>&1 &
  local cpid=$!
  bg_track "$cpid"
  sleep 4
  kill -0 "$cpid" 2>/dev/null || { cat consumer.log; die "Consumer exited early"; }

  step 6 "Run the producer"
  run_t 120 python3 producer.py || die "Producer failed"

  step 7 "Consumer output"
  local i=0
  while ! grep -q "Received Event: 3" consumer.log && [ "$i" -lt 30 ]; do sleep 1; i=$((i + 1)); done
  run cat consumer.log
  grep -q "Received Event: 3" consumer.log || die "The consumer did not receive the 3 events"
  info "Stopping the consumer (it runs until stopped, like a real service)"
  kill_pid "$cpid"
  cp consumer.log "$LAB_RESULTS/" 2>/dev/null
  note_ok "Kafka producer sent 3 events and the consumer received them on topic $topic"
}
