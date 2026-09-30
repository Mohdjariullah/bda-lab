#!/usr/bin/env bash
# Lab 3 - Basic HDFS Commands & File Operations (exact commands from the manual)

lab_main() {
  step 1 "Start NameNode and DataNode daemons (start-dfs.sh)"
  ensure_hdfs_running || die "HDFS is not available"

  lab_workdir lab03

  step 2 "Create a directory structure in HDFS"
  hdfs_cmd -mkdir -p /user/hadoop/lab_data || die "mkdir failed"

  step 3 "Create a local sample file"
  show 'echo "Hadoop HDFS File System Demonstration File" > sample_local.txt'
  echo "Hadoop HDFS File System Demonstration File" > sample_local.txt
  run cat sample_local.txt

  step 4 "Write (upload) the file from the local machine to HDFS"
  hdfs_put sample_local.txt /user/hadoop/lab_data/ || die "put failed"

  step 5 "List HDFS directory contents"
  hdfs_cmd -ls /user/hadoop/lab_data/

  step 6 "Read file contents directly from HDFS"
  hdfs_cmd -cat /user/hadoop/lab_data/sample_local.txt

  step 7 "Copy the file inside HDFS"
  hdfs_cp /user/hadoop/lab_data/sample_local.txt /user/hadoop/lab_data/backup.txt || die "cp failed"
  hdfs_cmd -ls /user/hadoop/lab_data/

  step 8 "Read (download) the file back to the local file system"
  hdfs_get /user/hadoop/lab_data/backup.txt ./downloaded_backup.txt || die "get failed"
  run cat ./downloaded_backup.txt
  cp downloaded_backup.txt "$LAB_RESULTS/"
  note_ok "HDFS read, write, copy and directory operations completed"
}
