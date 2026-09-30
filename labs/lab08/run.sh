#!/usr/bin/env bash
# Lab 8 - Processing and Word Count on Apache Spark (manual: spark_lab.py)

lab_main() {
  ensure_spark || die "Spark is not available"
  lab_workdir lab08
  cp "$LAB_DIR/spark_lab.py" .

  step 1 "Program source"
  show "cat spark_lab.py"; cat spark_lab.py

  step 2 "Run with spark-submit"
  run_t 600 "$SPARK_SUBMIT" spark_lab.py || die "Spark job failed"
  "$SPARK_SUBMIT" spark_lab.py > "$LAB_RESULTS/spark_output.txt" 2>/dev/null || true
  note_ok "Spark RDD sum and DataFrame word count completed"
}
