#!/usr/bin/env bash
# Lab 7 - Hive HiveQL operations (7a) and a Java UDF (7b), programs from the manual

_hive_guava_fix() {
  # Hive 3.1.x ships guava 19; Hadoop 3.2+ needs guava 27+. Known crash:
  # NoSuchMethodError: com.google.common.base.Preconditions.checkArgument
  local old new
  old=$(ls "$HIVE_HOME"/lib/guava-19*.jar 2>/dev/null | head -n1)
  new=$(ls "$HADOOP_HOME"/share/hadoop/common/lib/guava-2[0-9]*.jar "$HADOOP_HOME"/share/hadoop/common/lib/guava-3[0-9]*.jar 2>/dev/null | head -n1)
  [ -n "$old" ] && [ -n "$new" ] || return 1
  fail "Guava conflict: Hive has $(basename "$old"), Hadoop has $(basename "$new")"
  fixmsg "Replacing Hive's guava jar with Hadoop's"
  if [ -w "$HIVE_HOME/lib" ]; then
    run mv "$old" "$old.bak" && run cp "$new" "$HIVE_HOME/lib/"
  else
    ensure_sudo && run sudo mv "$old" "$old.bak" && run sudo cp "$new" "$HIVE_HOME/lib/"
  fi
}

# _derby_dir : where the embedded Derby metastore is. Default: metastore_db in
# the current directory. A hive-site.xml can pin it (databaseName=/some/path).
_derby_dir() {
  local site="$HIVE_HOME/conf/hive-site.xml" url=""
  if [ -f "$site" ]; then
    url=$(tr -d '\n' < "$site" | grep -oE '<name>javax\.jdo\.option\.ConnectionURL</name>[[:space:]]*<value>[^<]*</value>' \
          | sed -E 's#.*<value>([^<]*)</value>.*#\1#')
  fi
  case "$url" in
    *databaseName=*) printf '%s' "$url" | sed -E 's/.*databaseName=([^;]*).*/\1/' ;;
    *) echo metastore_db ;;
  esac
}
_hive_metastore_init() {
  # the embedded Derby metastore lives in the current directory (metastore_db)
  local dbdir; dbdir=$(_derby_dir)
  case "$dbdir" in jdbc:*|*://*) ok "Metastore is an external database ($dbdir), nothing to initialise here"; return 0 ;; esac
  if [ "$dbdir" != metastore_db ]; then
    info "hive-site.xml pins the Derby metastore to $dbdir"
    [ -d "$dbdir" ] && ok "Metastore already initialised in $dbdir" && return 0
  fi
  # Derby keeps a lock file in metastore_db/ while a Hive session is open.
  # If none is open, the file is only a leftover and would block this session.
  if [ -f metastore_db/db.lck ] || [ -f metastore_db/dbex.lck ]; then
    if pgrep -f "HiveMetaStore|org.apache.hadoop.hive.cli|HiveServer2" >/dev/null 2>&1; then
      warn "Another Hive session is open on this metastore; if this lab fails with a Derby lock error, close it first"
    else
      info "Removing the Derby lock file left by the last session (no Hive process is running)"
      rm -f metastore_db/db.lck metastore_db/dbex.lck
    fi
  fi
  if [ ! -d metastore_db ]; then
    if [ -x "$HIVE_HOME/bin/schematool" ]; then
      fixmsg "Initialising the Derby metastore schema (first run in this directory)"
      run_t 300 "$HIVE_HOME/bin/schematool" -dbType derby -initSchema || warn "schematool failed, Hive may create the schema itself"
    fi
  else
    ok "Metastore already initialised in $PWD/metastore_db"
  fi
}

# _hive ARGS... : run a HiveQL file or statement.
#   Hive 2.x / 3.x : the Hive CLI, MapReduce engine, framework chosen by ensure_mapreduce
#   Hive 4.x       : "hive" is Beeline. An embedded HiveServer2 (jdbc:hive2://) runs the
#                    same scripts without a separate server process.
#
# Heap: the Hive CLI starts its JVM with HADOOP_HEAPSIZE=256 (MB). In local
# MapReduce mode the map task runs inside that same JVM and allocates
# mapreduce.task.io.sort.mb (100 MB by default), which ends in
# "java.lang.OutOfMemoryError: Java heap space" and "return code 2 from
# MapRedTask". A bigger heap and a small sort buffer avoid it.
: "${HIVE_HEAP_MB:=1024}"
_hive() {
  local conf=(--hiveconf mapreduce.framework.name="${MR_MODE:-local}" --hiveconf mapreduce.task.io.sort.mb=32)
  if [ "${HIVE_IS_4:-0}" = 1 ]; then
    run_t 900 env HADOOP_HEAPSIZE="$HIVE_HEAP_MB" HADOOP_HEAPSIZE_MAX="$HIVE_HEAP_MB" \
      "$HIVE_HOME/bin/beeline" -u "jdbc:hive2://" --silent=false "${conf[@]}" "$@"
  else
    run_t 900 env HADOOP_HEAPSIZE="$HIVE_HEAP_MB" HADOOP_HEAPSIZE_MAX="$HIVE_HEAP_MB" \
      "$HIVE_HOME/bin/hive" "${conf[@]}" --hiveconf hive.execution.engine=mr "$@"
  fi
}
# _hive_quiet "SQL" : results only (no banners), for the results file
_hive_quiet() {
  local conf=(--hiveconf mapreduce.framework.name="${MR_MODE:-local}" --hiveconf mapreduce.task.io.sort.mb=32)
  if [ "${HIVE_IS_4:-0}" = 1 ]; then
    timeout 600 env HADOOP_HEAPSIZE="$HIVE_HEAP_MB" HADOOP_HEAPSIZE_MAX="$HIVE_HEAP_MB" \
      "$HIVE_HOME/bin/beeline" -u "jdbc:hive2://" --silent=true --outputformat=tsv2 "${conf[@]}" -e "$1" 2>/dev/null
  else
    timeout 600 env HADOOP_HEAPSIZE="$HIVE_HEAP_MB" HADOOP_HEAPSIZE_MAX="$HIVE_HEAP_MB" \
      "$HIVE_HOME/bin/hive" -S "${conf[@]}" --hiveconf hive.execution.engine=mr -e "$1" 2>/dev/null
  fi
}
_hive_log() { echo "${HIVE_LOG_FILE:-/tmp/$(id -un)/hive.log}"; }
# _hive_error PATTERN : did the last run fail with this error (screen output or hive.log)?
_hive_error() {
  log_has "$1" 300 && return 0
  [ -f "$(_hive_log)" ] && tail -n 400 "$(_hive_log)" | grep -qE "$1"
}
# _hive_script FILE : run a HiveQL file; on the known failures fix and run again (bounded)
_hive_script() {
  local f=$1 n=0
  while :; do
    _hive -f "$f" && return 0
    n=$((n + 1)); [ "$n" -gt "$MAX_FIX_ATTEMPTS" ] && return 1
    if _hive_error 'OutOfMemoryError: Java heap space'; then
      fail "Hive ran out of Java heap while running the job inside the CLI JVM (local mode)"
      HIVE_HEAP_MB=$((HIVE_HEAP_MB * 2)); [ "$HIVE_HEAP_MB" -gt 3072 ] && HIVE_HEAP_MB=3072
      note_fix "Running Hive again with HADOOP_HEAPSIZE=$HIVE_HEAP_MB"
    elif _hive_error 'Preconditions\.checkArgument' && _hive_guava_fix; then
      info "Running Hive again after the Guava fix"
    elif _hive_error 'Another instance of Derby may have already booted|db\.lck'; then
      fail "The Derby metastore is locked by another Hive process"
      note_fix "Stopping other Hive CLI processes and removing the lock"
      pkill -f "org.apache.hadoop.hive.cli.CliDriver" 2>/dev/null; sleep 2
      rm -f metastore_db/db.lck metastore_db/dbex.lck
    else
      warn "Last error lines from $(_hive_log):"
      grep -E 'ERROR|Exception' "$(_hive_log)" 2>/dev/null | tail -n 8
      return 1
    fi
  done
}

lab_main() {
  ensure_hdfs_running || die "HDFS is not available"
  ensure_mapreduce
  ensure_tool hive || die "Hive is not installed. Searched: $SEARCH_ROOTS"
  export HIVE_HOME
  local hv; hv=$(version_from_path "$HIVE_HOME")
  [ -n "$hv" ] || hv=$(ls "$HIVE_HOME"/lib/hive-exec-*.jar 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)
  info "Hive version: ${hv:-unknown}"
  HIVE_IS_4=0
  if version_ge "${hv:-0}" 4.0; then
    HIVE_IS_4=1
    note_warn "Hive $hv: the 'hive' command is Beeline. Scripts run through an embedded HiveServer2 (jdbc:hive2://)."
  fi
  if [ "${JAVA_MAJOR:-8}" -gt 8 ] && [ "$HIVE_IS_4" = 0 ]; then
    warn "Hive $hv works best with Java 8, current Java is $JAVA_MAJOR"
    local before=$JAVA_MAJOR
    if ensure_java "8" >/dev/null 2>&1 && [ "$JAVA_MAJOR" != "$before" ]; then
      note_fix "Switched to Java $JAVA_MAJOR for Hive ($JAVA_HOME)"
    else
      warn "No Java 8 found, continuing with Java $JAVA_MAJOR"
    fi
  fi
  _hive_guava_fix || true

  lab_workdir lab07
  rm -rf src classes; cp -r "$LAB_DIR/src" .
  cp "$LAB_DIR/emp_data.csv" "$LAB_DIR/lab7a_hiveql.hql" "$LAB_DIR/lab7b_udf.hql" .
  sed -i "s#/home/hadoop/emp_data.csv#$LAB_WORK/emp_data.csv#" lab7a_hiveql.hql
  sed -i "s#/path/to/MaskSalaryUDF.jar#$LAB_WORK/MaskSalaryUDF.jar#" lab7b_udf.hql
  # 7b runs in a new Hive session, so it must select the database first
  grep -qi '^USE lab_hive' lab7b_udf.hql || sed -i '1i USE lab_hive;' lab7b_udf.hql
  local hiveexec; hiveexec=$(ls "$HIVE_HOME"/lib/hive-exec-*.jar 2>/dev/null | head -n1)
  [ -n "$hiveexec" ] || die "hive-exec jar not found in $HIVE_HOME/lib"

  step 1 "Hive warehouse directories in HDFS"
  hdfs_cmd -mkdir -p /tmp /user/hive/warehouse
  hdfs_cmd -chmod g+w /tmp /user/hive/warehouse

  step 2 "Metastore"
  _hive_metastore_init

  step 3 "Lab 7a: HiveQL DDL/DML (data: emp_data.csv)"
  run cat emp_data.csv
  show "cat lab7a_hiveql.hql"; cat lab7a_hiveql.hql
  info "Removing rows from a previous run, so the LOAD does not append duplicates"
  _hive -e "CREATE DATABASE IF NOT EXISTS lab_hive; DROP TABLE IF EXISTS lab_hive.employee;" || true
  _hive_script lab7a_hiveql.hql || die "Hive failed (see the log)"

  step 4 "Lab 7b: compile the Java UDF and build MaskSalaryUDF.jar"
  show "cat src/MaskSalaryUDF.java"; cat src/MaskSalaryUDF.java
  mkdir -p classes
  run_as "javac -classpath $(basename "$hiveexec"):\$(hadoop classpath) -d classes src/MaskSalaryUDF.java" \
    javac -classpath "$hiveexec:$(hadoop_classpath)" -d classes src/MaskSalaryUDF.java || die "UDF compilation failed"
  run_sh "jar cvf MaskSalaryUDF.jar -C classes ." || die "jar failed"

  step 5 "Lab 7b: register and run the UDF in Hive"
  show "cat lab7b_udf.hql"; cat lab7b_udf.hql
  _hive_script lab7b_udf.hql || die "Hive UDF query failed"

  step 6 "Save the query results to $LAB_RESULTS/hive_output.txt"
  local q1="SELECT dept, COUNT(*) as total_emp, AVG(salary) as avg_sal FROM employee GROUP BY dept HAVING avg_sal > 50000;"
  local q2="SELECT name, mask_sal(CAST(salary AS STRING)) FROM employee;"
  {
    echo "-- $q1"
    _hive_quiet "USE lab_hive; $q1"
    echo
    echo "-- $q2"
    _hive_quiet "USE lab_hive; ADD JAR $LAB_WORK/MaskSalaryUDF.jar; CREATE TEMPORARY FUNCTION mask_sal AS 'com.lab.hive.MaskSalaryUDF'; $q2"
  } > "$LAB_RESULTS/hive_output.txt" 2>/dev/null
  run cat "$LAB_RESULTS/hive_output.txt"
  note_ok "Hive table created and loaded, aggregation run, UDF mask_sal applied"
}
