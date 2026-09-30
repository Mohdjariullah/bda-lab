#!/usr/bin/env bash
# Lab 1 - Installation, Configuration and Verification (manual: lab1_setup.py)

lab_main() {
  step 1 "Python and pip"
  ensure_python || die "Python is not available"

  step 2 "NumPy, Pandas, Matplotlib, Seaborn  (manual: pip3 install numpy pandas matplotlib seaborn)"
  ensure_pymods numpy:numpy:python3-numpy pandas:pandas:python3-pandas \
                matplotlib:matplotlib:python3-matplotlib seaborn:seaborn:python3-seaborn \
    || die "Required Python packages are missing"

  step 3 "Java (prerequisite for Hadoop)"
  if ensure_java "8 11 17"; then note_ok "Java $JAVA_MAJOR at $JAVA_HOME"; else note_warn "No JDK found. Labs 3 to 7 need one (sudo apt install openjdk-8-jdk)."; fi

  step 4 "Single-node Hadoop"
  if ensure_tool hadoop; then
    export HADOOP_CONF_DIR="$(hadoop_conf_dir)"
    fix_hadoop_env_java
    run_sh "$HADOOP_HOME/bin/hadoop version | head -n 3"
    note_ok "Hadoop found at $HADOOP_HOME"
  else
    note_warn "Hadoop not found. Labs 3, 4 and 7 will try to locate it again or report it as missing."
  fi

  lab_workdir lab01
  cp "$LAB_DIR/lab1_setup.py" .

  step 5 "Verification program (lab1_setup.py)"
  show "cat lab1_setup.py"; cat lab1_setup.py
  run python3 lab1_setup.py || die "Verification program failed"
  python3 lab1_setup.py > "$LAB_RESULTS/lab1_output.txt" 2>&1
  note_ok "NumPy and Pandas verified"
}
