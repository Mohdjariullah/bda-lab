#!/usr/bin/env bash
# Lab 9 - Spark Structured Streaming on a retail dataset (manual: structured_streaming.py)

# Spark reads log4j2.properties from SPARK_CONF_DIR, so the files go into a
# private configuration folder and the spark-submit command stays the plain one.
_write_quiet_log4j() {
  local d="$STATE_DIR/spark-conf-quiet"; mkdir -p "$d"
  export SPARK_CONF_DIR="$d"
  # The program only streams for 10 seconds. With Spark's default 200 shuffle
  # partitions the first micro-batch can take longer than that on a lab PC and
  # no table is printed. These are settings of the PC, not of the program, so
  # they live in the configuration folder and the command stays the manual's
  # "spark-submit structured_streaming.py".
  printf 'spark.sql.shuffle.partitions %s\nspark.ui.enabled false\n' "${1:-4}" > "$d/spark-defaults.conf"
  cat > "$d/log4j2.properties" <<'L4J'
rootLogger.level = warn
rootLogger.appenderRef.stdout.ref = console
appender.console.type = Console
appender.console.name = console
appender.console.target = SYSTEM_ERR
appender.console.layout.type = PatternLayout
appender.console.layout.pattern = %d{yy/MM/dd HH:mm:ss} %p %c{1}: %m%n
logger.exec.name = org.apache.spark.executor.Executor
logger.exec.level = off
logger.mbe.name = org.apache.spark.sql.execution.streaming
logger.mbe.level = off
logger.w2.name = org.apache.spark.sql.execution.datasources.v2.WriteToDataSourceV2Exec
logger.w2.level = off
logger.sched.name = org.apache.spark.scheduler
logger.sched.level = off
L4J
  cat > "$d/log4j.properties" <<'L4J'
log4j.rootCategory=WARN, console
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p %c{1}: %m%n
log4j.logger.org.apache.spark.executor.Executor=OFF
log4j.logger.org.apache.spark.sql.execution.streaming=OFF
log4j.logger.org.apache.spark.sql.execution.datasources.v2.WriteToDataSourceV2Exec=OFF
log4j.logger.org.apache.spark.scheduler=OFF
L4J
}

# The manual program calls query.awaitTermination(10) and then exits, so Spark
# stops the JVM while the query is still running. Spark reports that as
# "Job N cancelled because SparkContext was shut down" with a long stack trace.
# It is not an error of the lab. This filter drops exactly that block and
# nothing else (any other error is shown in full).
_hide_shutdown_noise() {
  awk '
    hold != "" {
      if ($0 ~ /SparkException: Job [0-9]+ cancelled because SparkContext was shut down/) { skip = 1; hold = ""; next }
      print hold; hold = ""; fflush()
    }
    /ERROR MicroBatchExecution: Query .* terminated with error/ { hold = $0; next }
    skip && ($0 ~ /^[[:space:]]+at / || $0 ~ /^[[:space:]]*$/) { next }
    { skip = 0; print; fflush() }
    END { if (hold != "") print hold }
  '
}

lab_main() {
  ensure_spark || die "Spark is not available"
  lab_workdir lab09
  cp "$LAB_DIR/structured_streaming.py" .
  local sdir=/tmp/retail_stream_input

  step 1 "Create the input directory"
  # only this lab's own folder, and only when it belongs to this user
  if [ -e "$sdir" ] && [ ! -O "$sdir" ]; then
    die "$sdir belongs to another user ($(stat -c %U "$sdir")). Ask that user to delete it, or restart the PC."
  fi
  rm -rf /tmp/retail_stream_input
  run mkdir -p "$sdir"

  step 2 "Program source"
  show "cat structured_streaming.py"; cat structured_streaming.py

  step 3 "JSON input file (the three transactions that give the totals of the manual)"
  cp "$LAB_DIR/batch1.json" "$sdir/batch1.json"
  run cat "$sdir/batch1.json"

  step 4 "Run the streaming program (it stops itself after 10 seconds)"
  _write_quiet_log4j 4
  run_pipe _hide_shutdown_noise timeout --foreground -k 5 300 "$SPARK_SUBMIT" structured_streaming.py \
    || die "Streaming job failed"
  if ! log_has 'Batch: [0-9]+' 400; then
    warn "No result table was printed in the 10 second window (slow machine)"
    note_fix "Running the job once more now that Spark's files are cached"
    _write_quiet_log4j 2
    run_pipe _hide_shutdown_noise timeout --foreground -k 5 300 "$SPARK_SUBMIT" structured_streaming.py \
      || die "Streaming job failed"
    log_has 'Batch: [0-9]+' 400 || die "The streaming program printed no result table"
  fi
  # the totals of the manual must be in the output
  tail -n 400 "$LAB_LOG" | grep -q '1245\.8' && tail -n 400 "$LAB_LOG" | grep -q '340\.5' && tail -n 400 "$LAB_LOG" | grep -q '185\.2' \
    || die "The result table does not show the expected totals (1245.8, 340.5, 185.2)"
  tail -n 400 "$LAB_LOG" | awk '/^Batch: /{keep=1} keep' > "$LAB_RESULTS/streaming_output.txt"
  note_ok "Structured Streaming: United Kingdom 1245.8, Germany 340.5, France 185.2"
}
