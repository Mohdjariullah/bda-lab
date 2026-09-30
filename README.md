# Big Data Lab Runner

One launcher for the Big Data Analytics practicals (Labs 1 to 10):
Python, HDFS, MapReduce, Pig, MongoDB, Hive, Spark, and Kafka.

Bash only. No `.exe`. No password storage. It runs each lab the way the
manual tells you to, and when a command fails it finds the problem, fixes
the environment, and runs the command again.

```
Launcher window            Lab window (one per lab)            Auth window (only when sudo is needed)
------------------         ---------------------------         ---------------------------------------
menu + progress     --->   runs every command, shows    --->   asks for your password, closes itself
"Lab 5 done"               the error, fixes the
"Password accepted"        environment, runs again
```

---

# Part 1 - For students (how to use it)

## What it does for you

You pick a lab from a menu. A new terminal window opens. In that window the
tool does exactly what you would do by hand:

1. It runs the first command (for example `hadoop version` or `pig -version`).
2. If the command fails because a path or a variable is wrong, it shows the
   error, finds the right value, prints the `export ...` line it used, and
   runs the command again.
3. It shows the program (with `cat`), compiles it, uploads the data, runs it,
   and prints the output.
4. Back in the first window (the launcher) you see the progress and, at the
   end, `Lab 5 done` or `Lab 5 failed`.

So you do not have to remember the order of commands, the `JAVA_HOME` value,
the `HADOOP_CLASSPATH` trick, or how to start HDFS. You watch it happen and
you learn the steps by reading them.

## Install (one click on Ubuntu)

Download `bigdata-lab-runner.sh`. Then either:

- Double-click it in the Files app and choose "Run", or "Run in Terminal".
- Or open a terminal and type:

```bash
bash bigdata-lab-runner.sh
```

That one file unpacks everything to `~/bigdata-lab-runner` and opens the menu.
Nothing is downloaded. Nothing is installed behind your back.

## Run a lab

```
./lab-runner            open the menu
./lab-runner 5          run Lab 5 now
./lab-runner 4          run Lab 4a then Lab 4b
./lab-runner all        run every lab, one after the other
./lab-runner diag       only check the machine, change nothing
```

The menu:

```
   1. Lab 1  - Installation and Verification
   2. Lab 2  - Data Visualization in Python
   3. Lab 3  - Basic HDFS Commands
  4a. Lab 4a - MapReduce Word Count
  4b. Lab 4b - MapReduce Weather (Max Temperature)
   5. Lab 5  - Apache Pig Java UDF
   6. Lab 6  - MongoDB NoSQL Operations
   7. Lab 7  - Hive HiveQL + Java UDF
   8. Lab 8  - Apache Spark Processing
   9. Lab 9  - Spark Structured Streaming
  10. Lab 10 - Kafka Event Streaming

    A. Run All Labs      D. System Diagnostics
    L. View a lab log    R. Rescan environment      0. Exit
```

## The password window (the part you keep missing in the HKS check)

Some steps need administrator rights (for example, to start a service). When
that happens, a small third window opens and asks for your Linux password.
You type it, press Enter, and the window closes by itself. The lab keeps
going in its own window, and the launcher shows `Password accepted`.

You never type the password in a script. The tool does not save it anywhere.

## If something is not found

Run `./lab-runner diag` first. It lists every tool it found, every Java
version, the ports in use, and how much disk and memory you have. It does not
start or change anything, so it is safe to run any time.

If the tool picks the wrong copy of Hadoop (some machines have two), open
`config/environment.conf` and set the right path, for example:

```
CFG_HADOOP_HOME="/home/cse/Desktop/hadoop-3.4.0"
```

Then press `R` in the menu to scan again.

## Good to know

- You can run a lab as many times as you want. Old outputs are deleted first,
  so a second run never fails with "output directory already exists".
- Every run is saved to a log in `logs/`. Press `L` in the menu to read one.
- The outputs (word counts, query results, the chart, and so on) are copied
  to `results/` so you can open them after the window closes.

---

# Part 2 - Technical reference (how it works)

## Design

Three roles, three windows, no blocking between them.

- **Launcher** (`lab-runner`): draws the menu, spawns a lab window, then
  polls `state/lab<ID>.progress`, `.status`, and `.pid`. It never waits on the
  lab process itself, because a spawned terminal detaches from its parent.
  Progress lines the lab writes appear in the launcher within half a second.
- **Lab window** (`core/labshell.sh <id>`): sources the core libraries, runs
  `labs/<lab>/run.sh` (which defines `lab_main`), writes progress and a final
  `OK`/`FAIL` status, and keeps a full log in `logs/lab<ID>_<ts>.log`.
- **Auth window** (`core/askpass-ui.sh`): opened only by `sudo`, through the
  `SUDO_ASKPASS` mechanism, when a step needs root.

## The three-terminal sudo flow

The runner never reads, stores, or guesses a password.

1. A lab step calls `ensure_sudo`, which runs `sudo -A -v`.
2. `sudo` runs the program named in `SUDO_ASKPASS`, which is `core/askpass.sh`.
3. `askpass.sh` creates a private FIFO in `state/` (mode 600, in memory only),
   then spawns the auth window (`askpass-ui.sh`) pointing at that FIFO.
4. You type the password in the auth window. It is written once into the FIFO
   and the window closes.
5. `askpass.sh` reads the one line from the FIFO, prints it to `sudo` on
   stdout, and deletes the FIFO. `sudo` verifies it.
6. `sudo` caches the credential for that lab terminal (the usual 15 minutes).
   A background `sudo -n -v` keepalive refreshes it so long labs never ask
   twice. The launcher prints `Password accepted`.

Safety details: the FIFO read has a 300 second timeout; an empty password
sends a `__CANCEL__` token so `sudo` fails cleanly; `HUP`/`INT`/`TERM` traps
in both scripts stop any hang; and if there is no graphical session, the
prompt falls back to `/dev/tty`. A wrong password just reopens the auth
window for the next `sudo` attempt.

## Tool selection (the deep edge cases)

For every tool (`hadoop`, `pig`, `hive`, `spark`, `kafka`) the resolver in
`core/detect.sh` picks exactly one installation, in this order, first valid
wins:

1. `CFG_<TOOL>_HOME` from `config/environment.conf` (your override).
2. `DETECTED_<TOOL>_HOME` cached in `state/detected.env` (an earlier choice).
3. `<TOOL>_HOME` from the shell, only if it points at a real install.
4. The executable on `PATH`.
5. A filesystem search under `SEARCH_ROOTS`.

"Real install" means the launcher **and** the tool's jars are present, so a
pip or npm shim in `/usr/local/bin` (launcher only) is rejected. When the
search finds several copies, the highest version wins; ties go to the newest
file. Tools are always run through the chosen absolute path, so a different
copy earlier on `PATH` cannot take over. The choice is cached, and printed as
the `export ...` lines the runner applied.

Java is handled the same way, but by version preference per lab: Hadoop, Pig,
and Hive prefer Java 8; Spark 4 and Kafka 4 prefer Java 17. `list_javas`
enumerates every JDK under `/usr/lib/jvm`, on `PATH`, and in `JAVA_HOME`.

## What it detects and repairs

| Problem | What the runner does |
|---|---|
| `JAVA_HOME` wrong or unset | Lists every JDK, picks the version the tool needs, exports it |
| `HADOOP_HOME` missing or broken | Searches the roots, uses the highest version, caches the choice |
| Several copies of a tool | Highest version wins; runs through the absolute path so PATH cannot interfere |
| `HADOOP_CONF_DIR` points to a non-config dir | Falls back to `etc/hadoop`, then `conf`, and says so |
| `hadoop-env.sh` has an invalid `JAVA_HOME` | Rewrites that line (backup kept) |
| `hdfs dfs` says `Unknown command: dfs` | Switches to `hadoop fs` for that machine |
| `fs.defaultFS` not set | Writes a pseudo-distributed `core-site.xml`/`hdfs-site.xml` (backups kept) |
| `fs.defaultFS` host does not resolve (hostname changed) | Rewrites the host to `localhost` (backup kept) |
| A NameNode from another Hadoop copy is running | Stops those daemons, starts the selected copy |
| NameNode name dir not writable by you | Repoints name/data dirs to `HADOOP_DATA_DIR`, or stops with a clear message when it belongs to another user |
| SSH to localhost denied | Creates a key and `authorized_keys`; if SSH still fails, starts daemons with `hdfs --daemon start` (no SSH needed) |
| NameNode never formatted | Formats once (only when the name dir is empty) |
| DataNode `Incompatible clusterIDs` | Clears the DataNode storage dir and restarts it |
| NameNode in safe mode | Waits, then leaves safe mode |
| HDFS `Permission denied` (you are not the HDFS superuser) | Re-runs the op with `HADOOP_USER_NAME` set to the superuser (simple auth) |
| YARN down, MRAppMaster missing, or the job hangs | Re-runs the job in local MapReduce mode through a private `HADOOP_CONF_DIR` copy (never edits your config) |
| Output dir or HDFS file already exists | Deletes it before the command runs again |
| Pig UDF: `WritableComparable not found` | Adds `hadoop-common` jars to the compile classpath |
| Pig cannot start with the installed Hadoop 3 | Re-runs with `HADOOP_HOME` hidden so Pig uses its bundled libs |
| Hive guava conflict with Hadoop 3 | Swaps the guava jar (backup kept; sudo window if the dir is read-only) |
| Hive local job `OutOfMemoryError` / return code 2 | Runs Hive with a bigger `HADOOP_HEAPSIZE` and a small `io.sort.mb`, then doubles the heap and retries |
| Hive metastore not initialised, stale Derby lock, pinned Derby path | `schematool -initSchema`; removes `db.lck` only when no Hive process runs; honours a `hive-site.xml` database path |
| Hive 4 (`hive` is Beeline) | Runs the same scripts through embedded HiveServer2 (`beeline -u jdbc:hive2://`) |
| MongoDB not running | `systemctl start mongod`, or a local `mongod --fork` with a private socket dir so another user's stale socket cannot block it |
| Kafka: ZooKeeper vs KRaft, storage not formatted, `InconsistentClusterIdException` | Detects the mode, formats storage, clears the stale log dir, reuses a broker that is already up |
| A port is held by a previous run of ours | Kills only that stale helper; anything else is reported and the lab stops |
| Spark missing | Uses the pip `pyspark` distribution, installs it when allowed |
| Python module missing | `pip --user`, then `--break-system-packages`, then `apt` with the password window |
| Any command hangs | Every long command has a timeout; fixes retry at most `MAX_FIX_ATTEMPTS` times |

## Loop and hang protection

- Every service wait and every long command runs under `timeout`.
- The generic "run, fix, run again" helper (`run_fix`) and the per-lab retry
  loops are bounded by `MAX_FIX_ATTEMPTS` (default 2). No fix can loop forever.
- Background helpers (feeders, brokers, the sudo keepalive) are tracked and
  killed when the lab ends.

## Layout

```
bigdata-lab-runner/
  lab-runner                launcher (menu, progress, "Lab N done")
  config/environment.conf   overrides (CFG_*_HOME) and switches
  core/
    common.sh               output, logging, run helpers, timeouts, retry
    terminal.sh             terminal-emulator detection and window spawning
    sudo.sh askpass.sh askpass-ui.sh   the password window
    detect.sh               tool and JDK discovery, Python packages
    hadoop.sh               Hadoop/HDFS/YARN checks and repairs
    services.sh             ports, MongoDB, Kafka/ZooKeeper
    spark.sh                Spark / PySpark
    labshell.sh             runs one lab inside its window
    diag/run.sh             diagnostics (read only)
  labs/lab01 ... lab10      one folder per lab: run.sh + the manual's sources and data
  logs/                     labNN_<timestamp>.log (labNN.log = latest)
  results/                  outputs copied back from HDFS / Spark / Mongo / Kafka
  state/                    progress files, detected paths, pids (private, mode 700)
```

Work files go under `~/bigdata_labs/<lab>`. HDFS paths are the ones from the
manual (`/user/hadoop/lab_data`, `/wc`, `/weather`, `/user/hadoop/pig_input`).

## Configuration switches

```
AUTO_START_SERVICES=1     # 0 = never start HDFS/YARN/Mongo/Kafka
AUTO_INSTALL_PY=1         # 0 = never pip/apt install
AUTO_WRITE_HADOOP_CONF=1  # 0 = never write core-site/hdfs-site
SERVICE_TIMEOUT=90        # seconds to wait for a service
MAX_FIX_ATTEMPTS=2        # fix-and-retry rounds per command
```

## Known limits

- Pig 0.17 has no MapReduce mode for Hadoop 3. The runner uses HDFS paths and
  MapReduce mode only when a `pig-*-core-h3.jar` build is present; otherwise it
  runs `pig -x local` with local paths, which is what the lab machines use.
- Hive 4 runs through Beeline embedded mode. Its default engine is Tez; if Tez
  is absent, jobs may fail there. Hive 2.x and 3.x (the usual lab installs)
  use the MapReduce engine and work as-is.
- Single machine (pseudo-distributed) only. Multi-node clusters are out of scope.
- If `sudo` is missing or your user is not a sudoer, root steps are reported as
  failed with a clear message; everything else still runs.
- MongoDB must be installed once (the runner starts it, and can `apt install`
  it only when a package is available in the configured repositories).

## Tested

On Ubuntu 24.04 with Hadoop 3.3.6, Pig 0.17.0, Hive 3.1.3, Kafka 3.9.0,
MongoDB 8.0.4, PySpark, and Java 8/17 side by side: all 11 lab entries pass
in `./lab-runner all`. The three-window flow (launcher, lab window, auth
window) and the wrong-password retry were verified with a real X display.
