#!/usr/bin/env bash
# core/spark.sh - Spark detection (a Spark install or the pip "pyspark" package)

spark_version() {
  local v; v=$(grep -oE 'Spark [0-9]+\.[0-9]+\.[0-9]+' "$SPARK_HOME/RELEASE" 2>/dev/null | awk '{print $2}')
  [ -n "$v" ] || v=$(ls "$SPARK_HOME"/jars/spark-core_*.jar 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)
  [ -n "$v" ] || v=$(version_from_path "$SPARK_HOME")
  echo "${v:-0}"
}

_pyspark_home() { python3 -c "import pyspark, os; print(os.path.dirname(pyspark.__file__))" 2>/dev/null; }

ensure_spark() {
  ensure_python || return 1
  JAVA_NEED_JDK=0 ensure_java "8 11 17 21" || return 1
  if ! ensure_tool spark; then
    warn "No Spark installation found on this machine"
    check "PySpark package (pip)"
    local ph; ph=$(_pyspark_home)
    if [ -z "$ph" ] || [ ! -x "$ph/bin/spark-submit" ]; then
      if [ "$AUTO_INSTALL_PY" = 1 ]; then
        fixmsg "Installing the pyspark package with pip (large download, a few minutes)"
        ensure_pymods pyspark:pyspark || { note_fail "pyspark could not be installed"; return 1; }
        ph=$(_pyspark_home)
      fi
    fi
    [ -n "$ph" ] && [ -x "$ph/bin/spark-submit" ] || { note_fail "Spark is not available"; return 1; }
    export SPARK_HOME="$ph"
    path_prepend "$SPARK_HOME/bin"
    save_detected DETECTED_SPARK_HOME "$SPARK_HOME"
    note_fix "Using the pip PySpark distribution as SPARK_HOME=$SPARK_HOME"
  fi
  export SPARK_HOME
  SPARK_SUBMIT="$SPARK_HOME/bin/spark-submit"
  SPARK_VER=$(spark_version); info "Spark version: $SPARK_VER"
  # Spark 4 needs Java 17+, Spark 3 works with 8/11/17
  if version_ge "$SPARK_VER" 4.0 && [ "${JAVA_MAJOR:-8}" -lt 17 ]; then
    warn "Spark $SPARK_VER needs Java 17 or newer"
    JAVA_NEED_JDK=0 ensure_java "17 21" || { note_fail "Spark $SPARK_VER needs Java 17+, none found"; return 1; }
  fi
  # avoid hostname lookups that hang the driver on lab machines; force the same python for driver and workers
  export SPARK_LOCAL_IP=127.0.0.1 PYSPARK_PYTHON=python3 PYSPARK_DRIVER_PYTHON=python3
  check "spark-submit"
  run_t 120 "$SPARK_SUBMIT" --version || { note_fail "spark-submit does not run (see the log)"; return 1; }
  note_ok "Spark ready: $SPARK_SUBMIT"
}
