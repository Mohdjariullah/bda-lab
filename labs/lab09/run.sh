#!/usr/bin/env bash
# Lab 9 - Spark Structured Streaming on a retail dataset (manual: structured_streaming.py)

_write_quiet_log4j() {
  cat > log4j2.properties <<'L4J'
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
  cat > log4j.properties <<'L4J'
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
  cp "$LAB_DIR/structured_streaming.py" "$LAB_DIR/retail_feeder.py" .
  local sdir=/tmp/retail_stream_input

  step 1 "Program source"
  show "cat structured_streaming.py"; cat structured_streaming.py

  step 2 "Prepare the stream directory $sdir"
  pkill -f "retail_feeder.py" 2>/dev/null && warn "Stopped a feeder left from a previous run"
  run rm -rf "$sdir"
  run mkdir -p "$sdir"

  step 3 "Start the feeder (writes one JSON transaction file per second)"
  show "python3 retail_feeder.py $sdir 40 > feeder.log &"
  python3 retail_feeder.py "$sdir" 40 > feeder.log 2>&1 &
  bg_track $!
  sleep 2
  run cat feeder.log
  run ls "$sdir"

  step 4 "Run the streaming job (the program stops itself after 10 seconds of streaming)"
  # The program only streams for 10 seconds. With Spark's default 200 shuffle partitions the
  # first micro-batch can take longer than that on a lab PC and nothing gets printed, so the
  # job is submitted with 4 partitions (a submit-time setting, the program is unchanged).
  # The log4j files keep Spark's INFO chatter off the screen; the filter above hides the shutdown trace.
  _write_quiet_log4j
  run_pipe _hide_shutdown_noise timeout --foreground -k 5 300 "$SPARK_SUBMIT" \
      --conf spark.sql.shuffle.partitions=4 --conf spark.ui.enabled=false \
      --driver-java-options "-Dlog4j2.configurationFile=file:$LAB_WORK/log4j2.properties -Dlog4j.configuration=file:$LAB_WORK/log4j.properties" \
      structured_streaming.py || die "Streaming job failed"
  if ! log_has 'Batch: [0-9]+' 400; then
    warn "No micro-batch table was printed in the 10 second window (slow machine)"
    note_fix "Running the job once more now that Spark's JVM files are cached"
    run_pipe _hide_shutdown_noise timeout --foreground -k 5 300 "$SPARK_SUBMIT" \
      --conf spark.sql.shuffle.partitions=2 --conf spark.ui.enabled=false \
      --driver-java-options "-Dlog4j2.configurationFile=file:$LAB_WORK/log4j2.properties -Dlog4j.configuration=file:$LAB_WORK/log4j.properties" \
      structured_streaming.py || die "Streaming job failed"
  fi

  step 5 "Files the feeder produced"
  run_sh "tail -n 5 feeder.log; ls $sdir | wc -l"
  cp feeder.log "$LAB_RESULTS/" 2>/dev/null
  note_ok "Structured Streaming aggregation (sum of TotalSpend per Country) completed"
}
