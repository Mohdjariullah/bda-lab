#!/usr/bin/env bash
# core/setup/run.sh - makes sure every tool the labs need is there AND works.
# Runs through core/labshell.sh like a lab (id "setup"), so it gets the same
# window, progress lines, log file and final banner.
#
# For Java 8, Hadoop, Pig, Hive, Spark and Kafka, in this order:
#   1. A copy that is already on this PC is looked for: where the shell says
#      it is (HADOOP_HOME, JAVA_HOME ...), the command on PATH, a disk search.
#   2. Every copy found is checked (usable version) and STARTED once. The first
#      one that works is used. Nothing is downloaded for that tool.
#   3. Only when no copy works, the runner downloads its own into $STACK_DIR
#      (default ~/bigdata_stack). No password is needed for that.
# A copy of the runner's own that stops working is removed and installed again.
# Copies on the PC are never changed and never deleted.
#
# Then the Python packages for labs 1, 2 and 10 are installed for this user.
# REUSE_INSTALLED=0 skips steps 1 and 2 (always the runner's own copies).

# ---- downloads (curl, wget or python3: whatever this PC has) ----------------
_url_ok() {   # does the URL exist?
  if have curl; then curl -fsIL -m 25 -o /dev/null "$1"
  elif have wget; then wget -q --spider --timeout=25 --tries=1 "$1"
  else python3 - "$1" <<'PY'
import sys, urllib.request
urllib.request.urlopen(urllib.request.Request(sys.argv[1], method="HEAD"), timeout=25)
PY
  fi
}
# _download URL DEST : big file, with a progress bar, resuming a partial file
_download() {
  local rc
  if have curl; then
    # --speed-*: a connection that stalls (under 2 kB/s for 60 s) is dropped and retried
    # from where it stopped, instead of hanging forever
    curl -fL --retry 5 --retry-delay 3 --connect-timeout 20 --speed-limit 2000 --speed-time 60 -C - -# -o "$2" "$1"; rc=$?
    # 33 = the file is already complete (range not satisfiable); the archive test decides
    [ "$rc" -eq 0 ] || [ "$rc" -eq 33 ]
  elif have wget; then
    wget -c --tries=5 --timeout=60 --progress=bar:force -O "$2" "$1"
  else
    python3 - "$1" "$2" <<'PY'
import sys, urllib.request
def hook(n, bs, total):
    if total > 0 and n % 400 == 0:
        sys.stderr.write("\r  %3d%%" % min(100, n * bs * 100 // total)); sys.stderr.flush()
urllib.request.urlretrieve(sys.argv[1], sys.argv[2], hook)
sys.stderr.write("\n")
PY
  fi
}

# _fetch_apache DEST REL : download REL from an Apache server
_fetch_apache() {
  local dest=$1 rel=$2 base
  for base in https://dlcdn.apache.org https://archive.apache.org/dist; do
    # dlcdn only keeps current releases: a 404 there is expected, so probe it quietly first
    _url_ok "$base/$rel" 2>/dev/null || continue
    _download "$base/$rel" "$dest" && return 0
  done
  return 1
}

# _sha512_check FILE REL : 0 = matches, 1 = mismatch, 2 = no checksum published
_sha512_check() {
  local want got tmp="$STACK_DIR/.downloads/.sha"
  fetch_url "https://archive.apache.org/dist/$2.sha512" "$tmp" 2>/dev/null || { rm -f "$tmp"; return 2; }
  want=$(tr -d ' \r\n' < "$tmp" | tr 'A-F' 'a-f' | grep -oE '[0-9a-f]{128}' | head -n1); rm -f "$tmp"
  [ -n "$want" ] || return 2
  got=$(sha512sum "$1" | cut -d' ' -f1)
  [ "$got" = "$want" ]
}

# _get_archive NAME FILE FETCHCMD... : download until the archive is intact (2 tries)
_get_archive() {
  local name=$1 file=$2 n=0; shift 2
  while :; do
    n=$((n + 1))
    if "$@" && tar -tzf "$file" >/dev/null 2>&1; then return 0; fi
    [ -f "$file" ] && { warn "The downloaded archive is incomplete or damaged, deleting it"; rm -f "$file"; }
    if [ "$n" -ge 2 ]; then note_fail "$name: download failed. Check the internet connection and run Setup again."; return 1; fi
    info "Trying the download again"
  done
}

# _unpack FILE DEST : unpack an archive that holds ONE top directory into DEST
_unpack() {
  local file=$1 dest=$2 tmp top
  tmp=$(mktemp -d "$STACK_DIR/.unpack.XXXXXX") || return 1
  if tar -xzf "$file" -C "$tmp"; then
    top=$(ls -1 "$tmp" | head -n1)
    if [ -n "$top" ] && [ -d "$tmp/$top" ]; then
      rm -rf "${dest:?}"
      mv "$tmp/$top" "$dest" && { rm -rf "$tmp"; return 0; }
    fi
  fi
  rm -rf "$tmp"
  return 1
}

# ---- Java 8 ----------------------------------------------------------------
_jdk_majors() { JAVA_SEARCH=1 list_javas | cut -f1 | sort -un | tr '\n' ' '; }
_jdk8_home()  { JAVA_SEARCH=1 list_javas | awk -F'\t' '$1==8 {print $2; exit}'; }

_install_jdk8() {
  local arch dest file="$STACK_DIR/.downloads/jdk8.tar.gz"
  case "$(uname -m)" in
    x86_64|amd64)  arch=x64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) note_fail "Java 8: no download for this processor type ($(uname -m))"; return 1 ;;
  esac
  dest=$(stack_home java)
  mkdir -p "$STACK_DIR/.downloads"
  note_info "Java 8: downloading the JDK (about 100 MB)"
  _get_archive "Java 8" "$file" _download \
    "https://api.adoptium.net/v3/binary/latest/8/ga/linux/$arch/jdk/hotspot/normal/eclipse" "$file" || return 1
  _unpack "$file" "$dest" || { note_fail "Java 8: unpacking failed"; return 1; }
  rm -f "$file"
  "$dest/bin/java" -version >/dev/null 2>&1 && "$dest/bin/javac" -version >/dev/null 2>&1 \
    || { note_fail "Java 8: the downloaded JDK does not start on this PC"; rm -rf "$dest"; return 1; }
  note_ok "Java 8 installed: $dest"
}

# ---- Apache tools ----------------------------------------------------------
_tool_rel() {   # path of the archive on the Apache servers
  case "$1" in
    hadoop) echo "hadoop/common/hadoop-$HADOOP_VER/hadoop-$HADOOP_VER.tar.gz" ;;
    pig)    echo "pig/pig-$PIG_VER/pig-$PIG_VER.tar.gz" ;;
    hive)   echo "hive/hive-$HIVE_VER/apache-hive-$HIVE_VER-bin.tar.gz" ;;
    spark)  echo "spark/spark-$SPARK_VER/spark-$SPARK_VER-bin-hadoop3.tgz" ;;
    kafka)  echo "kafka/$KAFKA_INSTALL_VER/kafka_$KAFKA_SCALA_VER-$KAFKA_INSTALL_VER.tgz" ;;
  esac
}
_tool_mb() { case "$1" in hadoop) echo 730;; pig) echo 230;; hive) echo 330;; spark) echo 400;; kafka) echo 115;; esac; }

# _tool_version NAME HOME : version read from the jar names (works without starting the tool)
_tool_version() {
  local f
  case "$1" in
    hadoop) f=$(ls "$2"/share/hadoop/common/hadoop-common-[0-9]*.jar 2>/dev/null | grep -v tests | head -n1) ;;
    pig)    f=$(ls "$2"/pig-[0-9]*.jar 2>/dev/null | head -n1) ;;
    hive)   f=$(ls "$2"/lib/hive-exec-[0-9]*.jar 2>/dev/null | head -n1) ;;
    spark)  f=$(ls "$2"/jars/spark-core_*.jar 2>/dev/null | head -n1) ;;
    kafka)  f=$(ls "$2"/libs/kafka_*.jar 2>/dev/null | grep -vE 'sources|javadoc|test' | head -n1) ;;
  esac
  basename "${f:-x}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1
}

# _tool_unusable NAME HOME : prints the reason and returns 0 when this copy cannot
# run the labs (the lab programs are written for these version ranges)
_tool_unusable() {
  local name=$1 home=$2 v; v=$(_tool_version "$name" "$home"); v=${v:-0}
  case "$name" in
    hadoop) version_ge "$v" 3.0.0 && ! version_ge "$v" 4.0.0 || { echo "version $v, the labs need Hadoop 3.x"; return 0; } ;;
    pig)    version_ge "$v" 0.16.0 || { echo "version $v, the labs need Pig 0.16 or newer"; return 0; } ;;
    hive)   version_ge "$v" 2.3.0 && ! version_ge "$v" 4.0.0 || { echo "version $v, the labs need Hive 2.3 to 3.x"; return 0; }
            # Hive 2/3 ships Guava 19, Hadoop 3 needs 27+: the jar must be swapped, which needs write access
            if ls "$home"/lib/guava-19*.jar >/dev/null 2>&1 && [ ! -w "$home/lib" ]; then
              echo "its Guava jar conflicts with Hadoop 3 and the folder is read-only"; return 0
            fi ;;
    spark)  version_ge "$v" 3.0.0 && ! version_ge "$v" 4.0.0 || { echo "version $v, the labs need Spark 3.x"; return 0; } ;;
    kafka)  version_ge "$v" 2.0.0 && ! version_ge "$v" 4.0.0 || { echo "version $v, the labs need Kafka 2.x or 3.x"; return 0; }
            [ -f "$home/config/zookeeper.properties" ] || { echo "it has no ZooKeeper configuration"; return 0; } ;;
  esac
  return 1
}

# _tool_works NAME HOME : does this copy really start? (output goes to the log only)
# It is started the way the labs start it: the chosen Java and Hadoop first in
# PATH and the runner's private configuration directories.
_tool_works() {
  local name=$1 home=$2 cmd
  case "$name" in
    hadoop) cmd=("$home/bin/hadoop" version) ;;
    pig)    cmd=("$home/bin/pig" -version) ;;
    hive)   cmd=("$home/bin/hive" --version) ;;
    spark)  cmd=("$home/bin/spark-submit" --version) ;;
    kafka)  cmd=("$home/bin/kafka-topics.sh" --version) ;;
  esac
  _logline "$ ${cmd[*]}"
  ( export JAVA_HOME="$SETUP_JAVA_HOME"
    if [ "$name" = hadoop ]; then export HADOOP_HOME="$home"; else export HADOOP_HOME="$SETUP_HADOOP_HOME"; fi
    export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$PATH"
    [ -x "$HADOOP_HOME/bin/hadoop" ] && prepare_tool_conf hadoop >/dev/null
    [ "$name" = hadoop ] || prepare_tool_conf "$name"
    cd "$STATE_DIR" && timeout 180 "${cmd[@]}" </dev/null ) >> "${LAB_LOG:-/dev/null}" 2>&1
}

_install_tool() {
  local name=$1 rel dest file rc free_kb
  rel=$(_tool_rel "$name"); dest=$(stack_home "$name")
  mkdir -p "$STACK_DIR"
  free_kb=$(df -Pk "$STACK_DIR" | awk 'NR==2 {print $4}')
  if [ "${free_kb:-0}" -lt $(( $(_tool_mb "$name") * 1024 * 4 )) ]; then
    note_fail "$name: not enough disk space in $STACK_DIR ($((free_kb / 1024)) MB free). Delete some files and run Setup again."
    return 1
  fi
  file="$STACK_DIR/.downloads/$(basename "$rel")"
  mkdir -p "$STACK_DIR/.downloads"
  note_info "$name: downloading (about $(_tool_mb "$name") MB)"
  _get_archive "$name" "$file" _fetch_apache "$file" "$rel" || return 1
  _sha512_check "$file" "$rel"; rc=$?
  if [ "$rc" -eq 1 ]; then
    warn "Checksum mismatch, downloading once more"
    rm -f "$file"
    _get_archive "$name" "$file" _fetch_apache "$file" "$rel" || return 1
    _sha512_check "$file" "$rel"; [ $? -eq 1 ] && { note_fail "$name: the download does not match its checksum"; rm -f "$file"; return 1; }
  fi
  note_info "$name: unpacking"
  _unpack "$file" "$dest" || { note_fail "$name: unpacking failed (disk full?)"; return 1; }
  rm -f "$file"
}

# _setup_tool NAME : make sure a working copy exists. Returns 1 if that is not possible.
_setup_tool() {
  local name=$1 home own why cand where v
  own=$(stack_home "$name")
  _tool_spec "$name"
  check "$name"

  # 1. the copy chosen earlier (forced in the config, the runner's own, or tested before)
  locate_home "$name"; home=$LOCATED_HOME
  if [ -n "$home" ]; then
    if [ -z "$SETUP_JAVA_HOME" ] || _tool_works "$name" "$home"; then
      note_ok "$name works: $home  ($LOCATE_SOURCE, version $(_tool_version "$name" "$home"))"
      return 0
    fi
    fail "$name in $home does not start any more"
    if [ "$LOCATE_SOURCE" = config ]; then
      note_fail "$name: CFG_$T_VAR in config/environment.conf points to a copy that does not start"
      return 1
    fi
    save_detected "DETECTED_$T_VAR" ""
    [ "$home" = "$own" ] && { note_fix "$name: removing the runner's damaged copy"; wipe_dir "$own"; }
  elif [ -e "$own" ]; then
    note_fix "$name: the runner's copy in $own is incomplete, removing it"
    wipe_dir "$own"
  fi

  # 2. copies that are already on this PC: test each one, use the first that works
  if [ "${REUSE_INSTALLED:-1}" = 1 ]; then
    while IFS=$'\t' read -r cand where; do
      [ -n "$cand" ] || continue
      if ! _valid_home "$cand" "$T_BIN"; then
        info "$name: $cand ($where) is not a complete installation, not used"
        continue
      fi
      v=$(_tool_version "$name" "$cand")
      if why=$(_tool_unusable "$name" "$cand"); then
        info "$name: $cand ($where) cannot be used: $why"
        continue
      fi
      if [ -n "$SETUP_JAVA_HOME" ] && _tool_works "$name" "$cand"; then
        save_detected "DETECTED_$T_VAR" "$cand"
        note_ok "$name: the copy already on this PC works and is used: $cand  ($where, version $v). Nothing to download."
        return 0
      fi
      info "$name: $cand ($where) does not start, not used"
    done < <(candidate_homes "$name")
    info "$name: no working copy on this PC"
  fi

  # 3. download the runner's own copy
  _install_tool "$name" || return 1
  if [ -n "$SETUP_JAVA_HOME" ] && ! _tool_works "$name" "$own"; then
    note_fail "$name was downloaded but does not start. The reason is at the end of the log."
    return 1
  fi
  save_detected "DETECTED_$T_VAR" "$own"
  note_ok "$name installed: $own"
}

# _setup_summary : one line per component, so the result can be read at a glance.
_setup_summary() {
  local t bad=0
  echo; echo "$LINE2"; echo " SETUP SUMMARY"; echo "$LINE2"
  _logline ""; _logline " SETUP SUMMARY"
  if [ -n "$SETUP_JAVA_HOME" ]; then note_ok "Java 8    $SETUP_JAVA_HOME"; else note_fail "Java      no working JDK 8 (needed by labs 3 to 10)"; bad=1; fi
  if have python3; then note_ok "Python    $(python3 --version 2>&1 | awk '{print $2}')"; else note_fail "Python    python3 not found (labs 1, 2, 8, 9, 10)"; bad=1; fi
  for t in hadoop pig hive spark kafka; do
    locate_home "$t"
    if [ -n "$LOCATED_HOME" ] && [ "${SETUP_BAD[$t]:-0}" = 0 ]; then note_ok "$(printf '%-9s' "$t") $LOCATED_HOME  ($LOCATE_SOURCE)"
    else note_fail "$(printf '%-9s' "$t") not working"; bad=1; fi
  done
  return $bad
}

# ---- main ------------------------------------------------------------------
lab_main() {
  local t failed=0
  declare -gA SETUP_BAD=()
  SETUP_JAVA_HOME=""

  step 1 "Java 8"
  SETUP_JAVA_HOME=$(_jdk8_home)
  if [ -n "$SETUP_JAVA_HOME" ]; then
    note_ok "Java 8 is already on this PC and works: $SETUP_JAVA_HOME. Nothing to download."
  else
    info "No working JDK 8 on this PC (found: $(_jdk_majors))"
    _install_jdk8 || failed=1
    SETUP_JAVA_HOME=$(_jdk8_home)
  fi
  [ -n "$SETUP_JAVA_HOME" ] && save_detected DETECTED_JAVA_HOME "$SETUP_JAVA_HOME"

  step 2 "Hadoop, Pig, Hive, Spark, Kafka"
  SETUP_HADOOP_HOME=""
  for t in hadoop pig hive spark kafka; do
    _setup_tool "$t" || { SETUP_BAD[$t]=1; failed=1; }
    if [ "$t" = hadoop ]; then locate_home hadoop; SETUP_HADOOP_HOME=$LOCATED_HOME; fi
  done
  rm -rf "$STACK_DIR/.downloads" 2>/dev/null

  step 3 "Python packages for labs 1, 2 and 10"
  if ensure_python; then
    ensure_pymods numpy pandas matplotlib seaborn \
      || { note_fail "Some Python packages for labs 1 and 2 could not be installed"; failed=1; }
    ensure_pymods kafka:kafka-python || ensure_pymods kafka:kafka-python-ng \
      || { note_fail "kafka-python (Lab 10) could not be installed"; failed=1; }
  else
    failed=1
  fi

  _setup_summary || failed=1
  [ "$failed" = 0 ] || { note_fail "Some parts could not be installed. The lines marked [✗] say which and why. Run Setup again after that is fixed: what already works is kept."; return 1; }
  note_ok "All lab software is installed and starts correctly."
  return 0
}
