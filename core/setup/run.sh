#!/usr/bin/env bash
# core/setup/run.sh - one-click installer for the lab software.
# Runs through core/labshell.sh like a lab (id "setup"), so it gets the same
# window, progress lines, log file and final banner.
#
# Installs only what is missing and skips what is already found:
#   apt      JDK 8 (fallback 11, 17), curl, tar, gpg, python3
#   Apache   Hadoop, Pig, Hive, Spark, Kafka  ->  $STACK_DIR (no root needed)
#   MongoDB  mongodb-org from the MongoDB apt repository (best effort)
#
# Versions can be changed in config/environment.conf (HADOOP_VER, ...).

: "${HADOOP_VER:=3.3.6}"
: "${PIG_VER:=0.17.0}"
: "${HIVE_VER:=3.1.3}"
: "${SPARK_VER:=3.5.3}"
: "${KAFKA_INSTALL_VER:=3.6.2}"
: "${KAFKA_SCALA_VER:=2.13}"
: "${SETUP_MIN_FREE_GB:=7}"

APT_UPDATED=0

# _root CMD... : run as root (directly when already root, otherwise through sudo)
_root() {
  if [ "$(id -u)" -eq 0 ]; then
    run env DEBIAN_FRONTEND=noninteractive "$@"
  else
    [ -n "${SUDO_OK:-}" ] || { ensure_sudo || return 1; SUDO_OK=1; }
    run sudo env DEBIAN_FRONTEND=noninteractive "$@"
  fi
}

_apt_update() { [ "$APT_UPDATED" = 1 ] && return 0; _root apt-get update || warn "apt-get update reported errors, continuing"; APT_UPDATED=1; }

_jdk_majors() { list_javas | cut -f1 | sort -un | tr '\n' ' '; }
_have_jdk()   { _jdk_majors | grep -qw "$1"; }

_install_jdk() {
  have apt-get || { note_fail "No JDK found and this system has no apt. Install JDK 8 manually."; return 1; }
  _apt_update
  if ! _have_jdk 8; then
    note_info "Installing OpenJDK 8"
    _root apt-get install -y openjdk-8-jdk-headless || warn "OpenJDK 8 is not available from apt on this system"
  fi
  if [ -z "$(_jdk_majors | tr -d ' ')" ]; then
    local v
    for v in 11 17; do
      note_info "Installing OpenJDK $v"
      _root apt-get install -y "openjdk-$v-jdk-headless" && break
    done
  fi
  [ -n "$(_jdk_majors | tr -d ' ')" ] || { note_fail "Could not install a JDK"; return 1; }
  note_ok "JDK installed (major versions: $(_jdk_majors))"
}

# ---- Apache downloads ------------------------------------------------------
# _fetch DEST REL : download REL from an Apache mirror, resuming a partial file.
_fetch() {
  local dest=$1 rel=$2 base rc
  for base in https://dlcdn.apache.org https://archive.apache.org/dist; do
    # dlcdn only keeps current releases: a 404 there is expected, so probe it quietly first
    curl -fsI -m 20 -o /dev/null "$base/$rel" || continue
    curl -fL --retry 5 --retry-delay 3 --connect-timeout 20 -C - -# -o "$dest" "$base/$rel"; rc=$?
    # 33 = the file is already complete (range not satisfiable); the checks below decide
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 33 ]; then return 0; fi
  done
  return 1
}

# _sha512_check FILE REL : 0 = matches, 1 = mismatch, 2 = no checksum published
_sha512_check() {
  local want got
  want=$(curl -fsL -m 30 "https://archive.apache.org/dist/$2.sha512" 2>/dev/null \
         | tr -d ' \r\n' | tr 'A-F' 'a-f' | grep -oE '[0-9a-f]{128}' | head -n1)
  [ -n "$want" ] || return 2
  got=$(sha512sum "$1" | cut -d' ' -f1)
  [ "$got" = "$want" ]
}

# _install_tool NAME VARNAME REL DIRNAME [SIZE_MB]
_install_tool() {
  local name=$1 var=$2 rel=$3 dir=$4 mb=${5:-?}
  local file="$STACK_DIR/.downloads/$(basename "$rel")" tmp n=0 rc
  mkdir -p "$STACK_DIR/.downloads"
  check "$name"
  note_info "$name: downloading (about $mb MB)"
  while :; do
    n=$((n + 1))
    if _fetch "$file" "$rel"; then
      _sha512_check "$file" "$rel"; rc=$?
      if [ "$rc" -eq 1 ]; then
        warn "Checksum mismatch, deleting the file"
        rm -f "$file"
      elif tar -tzf "$file" >/dev/null 2>&1; then
        [ "$rc" -eq 2 ] && warn "No checksum published for this file, archive integrity checked instead"
        break
      else
        warn "Archive is damaged, deleting the file"
        rm -f "$file"
      fi
    fi
    if [ "$n" -ge 2 ]; then note_fail "$name: download failed (see messages above)"; return 1; fi
    info "Trying the download again ($n/2 failed)"
  done
  note_info "$name: unpacking into $STACK_DIR"
  tmp=$(mktemp -d "$STACK_DIR/.unpack.XXXXXX") || return 1
  if tar -xzf "$file" -C "$tmp" && [ -d "$tmp/$dir" ]; then
    rm -rf "${STACK_DIR:?}/$dir"
    mv "$tmp/$dir" "$STACK_DIR/$dir"
  else
    rm -rf "$tmp"; note_fail "$name: unpacking failed"; return 1
  fi
  rm -rf "$tmp" "$file"
  save_detected "DETECTED_$var" "$STACK_DIR/$dir"
  note_ok "$name installed: $STACK_DIR/$dir"
}

# ---- MongoDB (best effort: only Lab 6 needs it) ----------------------------
_install_mongo() {
  have mongod && return 0
  have apt-get || { note_warn "MongoDB: no apt on this system, skipped (only Lab 6 needs it)"; return 0; }
  check "MongoDB"
  local mv="" key cn
  [ -r /etc/os-release ] && . /etc/os-release
  cn="${VERSION_CODENAME:-}"
  case "${ID:-}:$cn" in
    ubuntu:focal|ubuntu:jammy) mv=7.0 ;;
    ubuntu:noble)              mv=8.0 ;;
  esac
  if [ -n "$mv" ]; then
    note_info "MongoDB $mv: adding the MongoDB apt repository"
    key="/usr/share/keyrings/mongodb-server-$mv.gpg"
    if _root bash -c "curl -fsSL https://pgp.mongodb.com/server-$mv.asc | gpg --dearmor --yes -o $key" \
       && _root bash -c "echo 'deb [ arch=amd64,arm64 signed-by=$key ] https://repo.mongodb.org/apt/ubuntu $cn/mongodb-org/$mv multiverse' > /etc/apt/sources.list.d/mongodb-org-$mv.list"; then
      APT_UPDATED=0; _apt_update
      note_info "MongoDB $mv: installing mongodb-org"
      _root apt-get install -y mongodb-org && { note_ok "MongoDB installed"; return 0; }
    fi
  fi
  _apt_update
  _root apt-get install -y mongodb && { note_ok "MongoDB installed (distribution package)"; return 0; }
  note_warn "MongoDB could not be installed automatically. Only Lab 6 needs it."
  return 0
}

# ---- main ------------------------------------------------------------------
_tool_missing() { locate_home "$1"; [ -z "$LOCATED_HOME" ]; }

lab_main() {
  local t failed=0 missing_tools="" pkgs=()

  step 1 "Checking what is already installed"
  for t in hadoop pig hive spark kafka; do
    if _tool_missing "$t"; then missing_tools="$missing_tools $t"; else ok "$t already installed: $LOCATED_HOME"; fi
  done
  local need_jdk=0; _have_jdk 8 || need_jdk=1
  if [ "$need_jdk" = 0 ]; then ok "JDK 8 already installed"; else info "JDK 8: not found"; fi
  have mongod && ok "MongoDB already installed" || info "MongoDB: not found"
  [ -n "$missing_tools" ] && info "To download:$missing_tools"

  if [ -n "$missing_tools" ]; then
    local free_kb need_kb=$((SETUP_MIN_FREE_GB * 1024 * 1024))
    mkdir -p "$STACK_DIR" || die "Cannot create $STACK_DIR"
    free_kb=$(df -Pk "$STACK_DIR" | awk 'NR==2 {print $4}')
    if [ "${free_kb:-0}" -lt "$need_kb" ]; then
      die "Not enough disk space in $STACK_DIR: $((free_kb / 1048576)) GB free, $SETUP_MIN_FREE_GB GB needed"
    fi
    ok "Disk space: $((free_kb / 1048576)) GB free in $STACK_DIR"
  fi

  step 2 "System packages"
  have curl    || pkgs+=(curl ca-certificates)
  have tar     || pkgs+=(tar)
  have gzip    || pkgs+=(gzip)
  have gpg     || pkgs+=(gnupg)
  have python3 || pkgs+=(python3 python3-pip)
  if [ "${#pkgs[@]}" -gt 0 ]; then
    if have apt-get; then
      note_info "Installing system packages: ${pkgs[*]}"
      _apt_update
      _root apt-get install -y "${pkgs[@]}" || { note_fail "Could not install: ${pkgs[*]}"; return 1; }
    else
      note_fail "Missing tools (${pkgs[*]}) and no apt to install them"; return 1
    fi
  fi
  if [ "$need_jdk" = 1 ]; then
    _install_jdk || return 1
  else
    ok "Nothing to install from apt"
  fi

  step 3 "Downloading and installing the Apache tools"
  if [ -n "$missing_tools" ]; then
    check "Internet access"
    run curl -fsI -m 25 https://archive.apache.org/dist/ -o /dev/null \
      || { note_fail "Cannot reach archive.apache.org. Check the internet connection and run Setup again."; return 1; }
    local k="$KAFKA_SCALA_VER-$KAFKA_INSTALL_VER"
    for t in $missing_tools; do
      case "$t" in
        hadoop) _install_tool Hadoop "HADOOP_HOME" "hadoop/common/hadoop-$HADOOP_VER/hadoop-$HADOOP_VER.tar.gz"      "hadoop-$HADOOP_VER"          730 || failed=1 ;;
        pig)    _install_tool Pig    "PIG_HOME"    "pig/pig-$PIG_VER/pig-$PIG_VER.tar.gz"                          "pig-$PIG_VER"                230 || failed=1 ;;
        hive)   _install_tool Hive   "HIVE_HOME"   "hive/hive-$HIVE_VER/apache-hive-$HIVE_VER-bin.tar.gz"          "apache-hive-$HIVE_VER-bin"   330 || failed=1 ;;
        spark)  _install_tool Spark  "SPARK_HOME"  "spark/spark-$SPARK_VER/spark-$SPARK_VER-bin-hadoop3.tgz"       "spark-$SPARK_VER-bin-hadoop3" 400 || failed=1 ;;
        kafka)  _install_tool Kafka  "KAFKA_HOME"  "kafka/$KAFKA_INSTALL_VER/kafka_$k.tgz"                         "kafka_$k"                    115 || failed=1 ;;
      esac
    done
    rmdir "$STACK_DIR/.downloads" 2>/dev/null
  else
    ok "Hadoop, Pig, Hive, Spark and Kafka are already installed"
  fi

  step 4 "MongoDB"
  _install_mongo

  step 5 "Verifying the installation"
  ensure_java "8 11 17" || failed=1
  for t in hadoop pig hive spark kafka; do
    if _tool_missing "$t"; then note_fail "$t: not found after setup"; failed=1
    else note_ok "$t: $LOCATED_HOME"; fi
  done
  if [ -n "${JAVA_HOME:-}" ]; then
    local hadoop_h spark_h
    locate_home hadoop; hadoop_h=$LOCATED_HOME
    if [ -n "$hadoop_h" ]; then
      run "$hadoop_h/bin/hadoop" version || { note_fail "hadoop does not start"; failed=1; }
    fi
    locate_home spark; spark_h=$LOCATED_HOME
    if [ -n "$spark_h" ]; then
      run "$spark_h/bin/spark-submit" --version || { note_fail "spark-submit does not start"; failed=1; }
    fi
  fi
  if have mongod || have mongosh || have mongo; then note_ok "MongoDB: installed"; else note_warn "MongoDB: not installed (only Lab 6 needs it)"; fi

  [ "$failed" = 0 ] || { note_fail "Some parts could not be installed. Fix the problem above and choose Setup again."; return 1; }
  ok "All lab software is installed. Choose a lab from the menu."
  return 0
}
