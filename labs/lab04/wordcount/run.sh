#!/usr/bin/env bash
# Lab 4a - Word Count Application (exact program and commands from the manual)

lab_main() {
  ensure_hdfs_running || die "HDFS is not available"
  ensure_mapreduce

  lab_workdir lab04_wordcount
  cp "$LAB_DIR/WordCount.java" .
  rm -f WordCount*.class wordcount.jar

  step 1 "Program source"
  show "cat WordCount.java"; cat WordCount.java

  step 2 "Set HADOOP_CLASSPATH and compile"
  show 'export HADOOP_CLASSPATH=$($HADOOP_HOME/bin/hadoop classpath)'
  export HADOOP_CLASSPATH="$(hadoop_classpath)"
  run_as 'javac -classpath $HADOOP_CLASSPATH -d . WordCount.java' \
    javac -classpath "$HADOOP_CLASSPATH" -d . WordCount.java || die "Compilation failed"
  run_sh "jar cvf wordcount.jar WordCount*.class" || die "jar failed"

  step 3 "Prepare the input data"
  show 'echo "hadoop is big data framework. mapreduce processes big data." > input.txt'
  echo "hadoop is big data framework. mapreduce processes big data." > input.txt
  hdfs_cmd -mkdir -p /wc/input
  hdfs_put input.txt /wc/input/ || die "put failed"

  step 4 "Run the MapReduce job ($MR_MODE mode)"
  run_mr_job wordcount.jar WordCount /wc/input /wc/output || die "MapReduce job failed"

  step 5 "Output"
  hdfs_cmd -cat /wc/output/part-r-00000
  hdfs_cmd -get -f /wc/output/part-r-00000 "$LAB_RESULTS/wordcount_output.txt"
  note_ok "WordCount output: /wc/output/part-r-00000 (copy in $LAB_RESULTS/wordcount_output.txt)"
}
