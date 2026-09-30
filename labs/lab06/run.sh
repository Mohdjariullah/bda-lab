#!/usr/bin/env bash
# Lab 6 - NoSQL Operations using MongoDB (manual script, run in the MongoDB shell)

# true when the manual script really ran: product 1 has the "sale" tag and product 2 is gone
_lab6_verify() {
  "$MONGO_SHELL" --quiet --eval 'var d = db.getSiblingDB("store_db"); var n = d.products.find({_id: 1, tags: "sale"}).count(); var m = d.products.find({_id: 2}).count(); print("VERIFY " + n + " " + m)' 2>/dev/null | grep -q "VERIFY 1 0"
}

lab_main() {
  lab_workdir lab06
  cp "$LAB_DIR/lab6_mongodb.js" .
  ensure_mongodb || die "MongoDB is not available"

  step 1 "Script source"
  show "cat lab6_mongodb.js"; cat lab6_mongodb.js

  step 2 "Reset the collection (so the insert does not fail on a duplicate _id)"
  run_t 60 "$MONGO_SHELL" --quiet --eval 'db.getSiblingDB("store_db").products.drop()' || warn "drop failed (collection may not exist yet)"

  step 3 "Run the script in the shell ($MONGO_SHELL < lab6_mongodb.js)"
  run_sh "$MONGO_SHELL --quiet < lab6_mongodb.js" || true
  if ! _lab6_verify; then
    fail "The 'use store_db' shell command is not accepted by this shell in script mode"
    note_fix "Rewriting it as db.getSiblingDB(\"store_db\") and running again"
    sed 's/^use store_db;$/db = db.getSiblingDB("store_db");/' lab6_mongodb.js > lab6_mongodb_fixed.js
    run_t 60 "$MONGO_SHELL" --quiet --eval 'db.getSiblingDB("store_db").products.drop()' >/dev/null 2>&1
    run_sh "$MONGO_SHELL --quiet < lab6_mongodb_fixed.js" || die "MongoDB script failed"
    _lab6_verify || die "The script did not produce the expected documents"
  fi

  step 4 "Final state of store_db.products"
  run_t 60 "$MONGO_SHELL" --quiet --eval 'db.getSiblingDB("store_db").products.find().forEach(printjson)'
  "$MONGO_SHELL" --quiet --eval 'db.getSiblingDB("store_db").products.find().forEach(printjson)' > "$LAB_RESULTS/products.json" 2>/dev/null
  note_ok "MongoDB CRUD, array update and aggregation completed"
}
