#!/usr/bin/env bash
# Lab 5 - Apache Pig User Defined Function (manual: CleanDataUDF.java + filter_script.pig)
#
# Mode: the manual runs Pig on HDFS (mapreduce mode). That only works when the Pig build
# matches the Hadoop version (pig-*-core-h3.jar for Hadoop 3). Otherwise the same script
# runs in local mode with local paths, which is what "pig -x local" does on the lab machines.

_pig_core_jar() {
  ls "$PIG_HOME"/pig-*-core-h3.jar "$PIG_HOME"/pig-*-core-h2.jar "$PIG_HOME"/pig-*-core-h1.jar 2>/dev/null | head -n1
}

_fix_udf_classpath() {
  if log_has 'org\.apache\.hadoop|WritableComparable'; then
    fail "Hadoop classes are missing from the compile classpath"
    local jars
    jars=$(find_bins '*/hadoop-common-*.jar' | grep -v -- '-tests' | head -n 3 | paste -sd: -)
    [ -n "$jars" ] || jars=$(find_bins '*/lib/h2/hadoop-*.jar' | paste -sd: -)
    [ -n "$jars" ] || { fail "No Hadoop jars found on this machine"; return 1; }
    UDF_CP="$UDF_CP:$jars"
    note_fix "Added Hadoop jars to the classpath"
    return 0
  fi
  return 1
}

_write_script() {   # _write_script local|mapreduce
  cp "$LAB_DIR/filter_script.pig" filter_script.pig
  sed -i "s#/path/to/CleanDataUDF.jar#$LAB_WORK/CleanDataUDF.jar#" filter_script.pig
  if [ "$1" = local ]; then
    sed -i "s#'/user/hadoop/pig_input/raw_logs.csv'#'$LAB_WORK/pig_input/raw_logs.csv'#; s#'/user/hadoop/pig_output'#'$LAB_WORK/pig_output'#" filter_script.pig
  fi
  show "cat filter_script.pig"; cat filter_script.pig
}

_run_pig_local() {
  rm -rf pig_output
  if run "$PIG_HOME/bin/pig" -x local filter_script.pig; then return 0; fi
  [ -n "${HADOOP_HOME:-}" ] || return 1
  # Pig 0.17 often refuses to start when a Hadoop 3 install is on PATH: use Pig's bundled Hadoop
  fail "Pig failed with the external Hadoop ($HADOOP_HOME) on PATH"
  note_fix "Retrying with Pig's bundled Hadoop libraries (HADOOP_HOME unset)"
  rm -rf pig_output
  run env -u HADOOP_HOME -u HADOOP_CONF_DIR -u HADOOP_PREFIX -u HADOOP_CLASSPATH PATH="$(path_without "$HADOOP_HOME")" \
      "$PIG_HOME/bin/pig" -x local filter_script.pig
}

lab_main() {
  ensure_java "8 11 17" || die "No JDK available"
  local have_hadoop=0
  if ensure_tool hadoop; then
    have_hadoop=1
    export HADOOP_CONF_DIR="$(hadoop_conf_dir)"
    fix_hadoop_env_java
  else
    warn "Hadoop not found. Pig will use its bundled Hadoop libraries (local mode only)."
  fi
  ensure_tool pig || die "Pig is not installed. Searched: $SEARCH_ROOTS"
  export PIG_HOME
  local pigjar; pigjar=$(_pig_core_jar)
  [ -n "$pigjar" ] || pigjar=$(ls "$PIG_HOME"/pig-*.jar 2>/dev/null | grep -v withouthadoop | head -n1)
  [ -n "$pigjar" ] || die "Pig core jar not found in $PIG_HOME"
  check "Pig core jar"; ok "$pigjar"

  lab_workdir lab05
  rm -rf src pig_input classes; cp -r "$LAB_DIR/src" "$LAB_DIR/pig_input" .

  step 1 "Raw data (pig_input/raw_logs.csv)"
  run cat pig_input/raw_logs.csv

  step 2 "UDF source"
  show "cat src/CleanDataUDF.java"; cat src/CleanDataUDF.java

  step 3 "Compile the UDF and build CleanDataUDF.jar"
  UDF_CP="$pigjar"
  [ "$have_hadoop" = 1 ] && UDF_CP="$UDF_CP:$(hadoop_classpath)"
  UDF_CP="$UDF_CP:$(ls "$PIG_HOME"/lib/*.jar "$PIG_HOME"/lib/h2/*.jar "$PIG_HOME"/lib/h3/*.jar 2>/dev/null | paste -sd: -)"
  mkdir -p classes
  local n=0
  while :; do
    if run_as "javac -classpath $(basename "$pigjar"):\$(hadoop classpath) -d classes src/CleanDataUDF.java" \
         javac -classpath "$UDF_CP" -d classes src/CleanDataUDF.java; then break; fi
    n=$((n + 1)); [ "$n" -gt "$MAX_FIX_ATTEMPTS" ] && die "UDF compilation failed"
    _fix_udf_classpath || die "UDF compilation failed"
  done
  run_sh "jar cvf CleanDataUDF.jar -C classes ." || die "jar failed"

  # ---- pick the run mode --------------------------------------------------
  local mode=local
  if [ "$have_hadoop" = 1 ] && ls "$PIG_HOME"/pig-*-core-h3.jar >/dev/null 2>&1 && hdfs_alive 2>/dev/null; then
    mode=mapreduce
  fi
  info "Pig run mode: $mode"

  if [ "$mode" = mapreduce ]; then
    step 4 "Pig script (HDFS paths, as in the manual)"
    _write_script mapreduce
    step 5 "Upload the raw data to HDFS"
    ensure_hadoop >/dev/null
    hdfs_cmd -mkdir -p /user/hadoop/pig_input
    hdfs_put pig_input/raw_logs.csv /user/hadoop/pig_input/
    hdfs_rm_if_exists /user/hadoop/pig_output
    step 6 "Run Pig (mapreduce mode)"
    if run_t 600 "$PIG_HOME/bin/pig" filter_script.pig; then
      step 7 "Output (/user/hadoop/pig_output)"
      hdfs_cmd -ls /user/hadoop/pig_output
      run_sh "$HADOOP_HOME/bin/hdfs dfs -cat /user/hadoop/pig_output/part-*"
      run_sh "$HADOOP_HOME/bin/hdfs dfs -cat /user/hadoop/pig_output/part-* > $LAB_RESULTS/pig_output.txt"
      note_ok "Pig UDF output stored in HDFS at /user/hadoop/pig_output"
      return 0
    fi
    fail "Pig mapreduce mode failed"
    note_fix "Falling back to local mode (pig -x local) with local paths"
    mode=local
  fi

  step 4 "Pig script (local paths)"
  _write_script local
  step 5 "Run Pig in local mode"
  _run_pig_local || die "Pig failed"

  step 6 "Output (pig_output/part-*)"
  run ls -l pig_output
  run_sh "cat pig_output/part-*"
  cat pig_output/part-* > "$LAB_RESULTS/pig_output.txt" 2>/dev/null
  note_ok "Pig UDF output stored in $LAB_WORK/pig_output"
}
