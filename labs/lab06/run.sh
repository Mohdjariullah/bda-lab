#!/usr/bin/env bash
# Lab 6 - NoSQL Operations using MongoDB (manual script: lab6_mongodb.js)
#
# MongoDB is used on Windows in this course, so nothing is installed or started
# here. The lab shows the script; the records are added by hand in MongoDB.

lab_main() {
  lab_workdir lab06
  cp "$LAB_DIR/lab6_mongodb.js" .
  cp "$LAB_DIR/lab6_mongodb.js" "$LAB_RESULTS/"

  run cat lab6_mongodb.js

  echo
  echo "# Run these statements in MongoDB on Windows (mongosh or the MongoDB Compass shell)."
  note_ok "MongoDB script shown (it is run in MongoDB on Windows). Copy: $LAB_RESULTS/lab6_mongodb.js"
}
