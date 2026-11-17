# Big Data Lab Runner

One launcher for all the Big Data Analytics practicals (Labs 1 to 10):
Python, HDFS, MapReduce, Pig, Hive, Spark and Kafka. (Lab 6, MongoDB, is done
on Windows: the tool only shows its script.)

You choose a lab from a menu. The tool runs every command of that lab for
you, in the correct order, in its own terminal window. When a command fails
(wrong `JAVA_HOME`, Hadoop not started, output folder already exists, and so
on), the tool shows you the error, fixes it, and runs the command again.

It is only Bash scripts. There is no `.exe` file. It never asks for a
password and never asks a question: you start it, it installs what it needs
in your own home folder, and it shows the output.

**Other copies of Hadoop, Hive, Pig, Spark, Kafka or Java on the PC do not
matter.** Many lab PCs already have some of them, in other versions or with a
broken configuration ("version mismatch", "environment is not configured").
The tool does not try to repair those. It uses its own copies in
`~/bigdata_stack`, in versions that are tested together, ignores every
setting the other copies left in the shell, and stops their daemons when
they block a port. If one of its own copies gets damaged, it removes that
copy and installs it again.

```
Window 1: LAUNCHER            Window 2: LAB WINDOW
(you type here)               (opens for each lab)
-------------------           ----------------------------
menu + progress        --->   runs each command and
"Lab 5 done"                  shows its output
```

**Contents**

- [Part 1 - Student guide](#part-1---student-guide)
  - [1. Before you start](#1-before-you-start)
  - [2. Open a terminal](#2-open-a-terminal)
  - [3. Get the files (choose Option A or Option B)](#3-get-the-files-choose-option-a-or-option-b)
  - [4. Install (one command)](#4-install-one-command)
  - [5. Start the tool next time](#5-start-the-tool-next-time)
  - [6. Use the menu](#6-use-the-menu)
  - [7. What you see in the lab window](#7-what-you-see-in-the-lab-window)
  - [8. The password window](#8-the-password-window)
  - [9. When the lab is finished](#9-when-the-lab-is-finished)
  - [10. What each lab does and the output you must see](#10-what-each-lab-does-and-the-output-you-must-see)
  - [11. Problems and solutions](#11-problems-and-solutions)
  - [12. Update, reset and uninstall](#12-update-reset-and-uninstall)
  - [13. Command cheat sheet](#13-command-cheat-sheet)
- [Part 2 - Technical reference](#part-2---technical-reference)

---

# Part 1 - Student guide

Read the steps in order. Each step tells you what to do and what you must see.

## 1. Before you start

You need:

| Item | Why | How to check |
|---|---|---|
| Ubuntu (or another Debian-based Linux) with a desktop | The tool opens new terminal windows | You can see the desktop and the app grid |
| Internet, the first time | The tool downloads its own Java 8, Hadoop, Pig, Hive, Spark and Kafka (about 2 GB, 5 to 30 minutes, once) | Open any web page |
| 5 GB of free disk space in your home folder | For those downloads | Nothing to do. Setup checks it |

You do **not** need a password, and you do not need to remove the Hadoop or
Kafka that is already on the PC.

You do **not** need to know the `export` commands, `JAVA_HOME`, or how to
start HDFS. The tool does this and shows you what it did.

## 2. Open a terminal

Press **Ctrl + Alt + T**.

A black or purple window opens. This is the terminal. You type commands here
and press **Enter** to run them.

> Tip: To paste into the terminal, use **Ctrl + Shift + V** (not Ctrl + V).

## 3. Get the files (choose Option A or Option B)

### Option A: with git (recommended, easy to update later)

Copy these lines, paste them into the terminal, and press **Enter**:

```bash
cd ~
git clone https://github.com/Mohdjariullah/bda-lab.git
cd bda-lab
```

If you see `Command 'git' not found`, install git first, then do Option A again:

```bash
sudo apt install -y git
```

(`sudo` asks for your Linux password. The letters do not show when you type.
This is normal. Type the password and press **Enter**.)

You must see a new folder: `/home/<your-name>/bda-lab`.

### Option B: without git (download a ZIP)

1. Open https://github.com/Mohdjariullah/bda-lab in the browser.
2. Click the green **Code** button, then click **Download ZIP**.
3. Open the **Files** app and go to **Downloads**.
4. Right-click `bda-lab-main.zip` and click **Extract Here**.
5. Right-click the new folder `bda-lab-main` and click **Open in Terminal**.

The terminal now opens inside that folder. Continue with Step 4.

> If you do not see **Open in Terminal**, open a terminal (Ctrl + Alt + T) and type:
> `cd ~/Downloads/bda-lab-main`

## 4. Install (one command)

In the terminal (inside the `bda-lab` folder), type:

```bash
bash install.sh
```

What this command does:

- It makes all the scripts executable.
- It adds a **Big Data Lab Runner** icon to your app grid (and to your Desktop).
- It does not install any software itself. The software is installed the first
  time you start the menu (see "Automatic setup" below).

At the end it asks:

```
Open the menu now? [Y/n]
```

Press **Enter** to open the menu now.

The first start checks which of its own tools are already installed. Then
the menu opens (see Step 6).

**Automatic setup.** If something is missing, the tool says
`Not installed yet: ...` and installs it at once, without asking. Everything
goes into `~/bigdata_stack` and belongs to you, so no password is needed:

- Java 8 (only when the PC has no working JDK 8).
- Hadoop 3.3.6, Pig 0.17.0, Hive 3.1.3, Spark 3.5.3 and Kafka 3.6.2.
- The Python packages for labs 1, 2 and 10 (numpy, pandas, matplotlib, seaborn, kafka-python).

Every tool is started once to prove that it works. A copy that does not
start is removed and installed again.

Setup ends with a **SETUP SUMMARY**: one line per tool, `[✓]` or `[✗]`. If a
line is `[✗]`, the line above the summary says why (for example no internet).
Choose **S** again after you fix it. What already works is kept.

To run it again later, choose **S** in the menu or type `./lab-runner setup`.
To turn the automatic start off, set `AUTO_SETUP=0` in
`config/environment.conf`.

## 5. Start the tool next time

Use one of these three ways:

1. **App grid:** press the **Super** (Windows) key, type `Big Data`, click **Big Data Lab Runner**.
2. **Desktop icon:** double-click **Big Data Lab Runner** on the Desktop.
   The first time, Ubuntu can show "Untrusted application". Right-click the
   icon and click **Allow Launching**, then double-click it again.
3. **Terminal:**

   ```bash
   cd ~/bda-lab
   ./lab-runner
   ```

   (For Option B the folder is `~/Downloads/bda-lab-main`.)

## 6. Use the menu

The menu looks like this:

```
============================================================
        BIG DATA ANALYTICS - LAB RUNNER
============================================================

Environment status:
  [✓] Java
  [✓] Python
  [✓] Hadoop
  [✓] HDFS configuration
  [✓] Pig
  [✓] Hive
  [✓] Spark
  [✓] Kafka

------------------------------------------------------------
Select a Lab
------------------------------------------------------------

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

    A. Run All Labs
    D. System Diagnostics
    L. View a lab log
    R. Rescan environment
   0. Exit

Enter choice:
```

**Environment status:** `[✓]` means the tool found it. `[✗]` means the
tool did not find it now. A `[✗]` is not always a problem: when you start a
lab, the tool searches again and tries to fix it.

**To run a lab:** type its number and press **Enter**.

| You type | Result |
|---|---|
| `5` | Runs Lab 5 |
| `4a` or `4b` | Runs one part of Lab 4 |
| `4` | Runs Lab 4a, then Lab 4b |
| `A` | Runs all labs, one after the other, and shows a summary at the end |
| `D` | Checks the PC and shows a report. It changes nothing |
| `L` | Shows the full log of a lab you ran before |
| `R` | Scans the PC again (use it after you install or move a tool) |
| `0` | Closes the tool |

When you choose a lab, **a second window opens**. The lab runs in that
window. The launcher window (the first one) shows short progress lines:

```
------------------------------------------------------------
Lab 3  - Basic HDFS Commands
[→] Opened a new terminal window for the lab. Watch the commands there.
    Progress:
    [✓] Java 8: /usr/lib/jvm/java-8-openjdk-amd64
    [✓] hadoop: /home/cse/Desktop/hadoop-3.4.0
    [FIX] HDFS started (NameNode + DataNode running)
    [✓] HDFS read, write, copy and directory operations completed
    [✓] Lab 3 done
[✓] Lab 3 done  (51s)

Press ENTER to return to the Lab Runner...
```

## 7. What you see in the lab window

The lab window shows every command before it runs, then the output of the
command. It is the same thing you would type by hand, so you can learn the
steps and write them in your record.

**How to read the lines:**

| Line starts with | Meaning |
|---|---|
| `$ command` | The command that runs now (this is what you would type) |
| `[CHECK]` | The tool checks one thing (for example, Java) |
| `[STEP 3]` | Step 3 of the lab manual |
| `[✓]` (green) | This part is correct |
| `[✗]` (red) | This part failed. Read the next lines: a fix usually follows |
| `[FIX]` (cyan) | The tool changed something to repair the problem |
| `[!]` (yellow) | A warning. The lab continues |
| `[→]` (blue) | Information |

**Example:** `JAVA_HOME` is wrong on the PC. You see this:

```
[CHECK] Java (preferred versions: 8 11 17)

$ java -version
bash: java: command not found

[!] Multiple JDKs found:
      Java 8   /usr/lib/jvm/java-8-openjdk-amd64
      Java 17  /usr/lib/jvm/java-17-openjdk-amd64
[FIX] export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64  (preferred Java 8)
[FIX] export PATH=$JAVA_HOME/bin:$PATH
[→] Re-running:

$ java -version
openjdk version "1.8.0_462"
[✓] Java 8: /usr/lib/jvm/java-8-openjdk-amd64
```

1. The tool runs the command the normal way. It fails.
2. It shows the error.
3. It shows the fix (the `export` lines). You can copy these lines to use them by hand.
4. It runs the command again. Now it works.

Do not close the lab window while the lab runs. If you close it, the lab stops
and the launcher shows `The lab window closed before the lab finished`.

## 8. The password window

There is none any more. Nothing the labs do needs administrator rights, so
the tool never asks for your password.

## 9. When the lab is finished

The lab window is plain. It shows only the commands that were run
(`$ command`), what they printed, and errors (`[✗]`). There is no header and
no "completed" message, so the window simply stops printing.

If the lab has its own window, it stays open until you press **Enter**
(nothing is printed while it waits), so you can read the output. When a lab
fails, the window says `Press ENTER to close this window...`.

The **launcher** window tells you the result:

```
[✓] Lab 5 done  (24s)
```

or, when something failed:

```
[✗] Lab 5 failed  (12s)
    What went wrong:
      - Pig is not installed. Searched: /home/student /home /opt ...
    Full log: /home/student/bda-lab/logs/lab05_20260101_101500.log
```

The lines under `What went wrong` are the errors of that lab. You do not
need to open the log to see them.

The full story (every check, fix and step) is always saved in the log file
`logs/lab05.log`. To see the extra lines in the lab window too, set
`LAB_RAW_OUTPUT=0` in `config/environment.conf`.

Press **Enter** in the launcher to go back to the menu.

**Where to find your work:**

| What | Where |
|---|---|
| The output of each lab (to show your teacher or copy to your record) | `bda-lab/results/<lab>/` |
| The source files, compiled classes and jars | `~/bigdata_labs/<lab>/` |
| The full log of each run (every command and every output) | `bda-lab/logs/` (press `L` in the menu) |
| Files in HDFS | The paths from the manual, for example `/user/hadoop/lab_data` |

To open the results folder, type in a terminal:

```bash
xdg-open ~/bda-lab/results
```

## 10. What each lab does and the output you must see

These are the real outputs from a test run. Your output must be the same (or
very close, for timing values).

### Lab 1 - Installation and Verification

Checks Python, pip, NumPy, Pandas, Matplotlib, Seaborn, Java and Hadoop, then
runs `lab1_setup.py`.

```
NumPy Mean: 30.0

Pandas DataFrame:
    ID     Name  Score
0  101    Alice     85
1  102      Bob     92
2  103  Charlie     78
```

Result file: `results/lab01/lab1_output.txt`

### Lab 2 - Data Visualization in Python

Runs `lab2_visualization.py` and makes a chart. The image opens by itself.

Result file: `results/lab02/visualization_output.png`

### Lab 3 - Basic HDFS Commands

Starts HDFS (if it is not running), then does `mkdir`, `put`, `ls`, `cat`,
`cp` and `get` in HDFS.

```
$ hdfs dfs -cat /user/hadoop/lab_data/sample_local.txt
Hadoop HDFS File System Demonstration File
```

Result file: `results/lab03/downloaded_backup.txt`

### Lab 4a - MapReduce Word Count

Compiles `WordCount.java`, makes `wordcount.jar`, puts the input in HDFS,
runs the job.

```
$ hdfs dfs -cat /wc/output/part-r-00000
big        2
data       2
framework  1
hadoop     1
is         1
mapreduce  1
processes  1
```

Result file: `results/lab04_wordcount/wordcount_output.txt`

### Lab 4b - MapReduce Weather (Max Temperature)

Compiles the Mapper, Reducer and Driver, runs the job on `sample_weather.txt`.

```
$ hdfs dfs -cat /weather/output/part-r-00000
2023    42
2024    45
```

Result file: `results/lab04_weather/weather_output.txt`

### Lab 5 - Apache Pig Java UDF

Compiles `CleanDataUDF.java`, makes `CleanDataUDF.jar`, runs `filter_script.pig`.
Row 3 (`@@@###$$$`) becomes empty, so the filter removes it.

```
$ cat pig_output/part-*
1,VALID USER SESSION ACTIVE
2,PURCHASE COMPLETED SUCCESSFULLY
```

Result file: `results/lab05/pig_output.txt`

### Lab 6 - MongoDB NoSQL Operations

MongoDB is used on Windows in this course. The tool does not install or
start MongoDB. It shows `lab6_mongodb.js` (insert, find, update, aggregate,
delete), and you run those statements in MongoDB on Windows yourself.

Copy of the script: `results/lab06/lab6_mongodb.js`

### Lab 7 - Hive HiveQL + Java UDF

7a creates the `lab_hive.employee` table, loads `emp_data.csv` and runs the
GROUP BY query. 7b compiles `MaskSalaryUDF.java` and uses it in a query.

```
Engineering     2       78500.0

Alice   XXXX-CONFIDENTIAL
Bob     XXXX-CONFIDENTIAL
```

This lab takes 2 to 3 minutes. Hive is slow to start. Wait.

Result file: `results/lab07/hive_output.txt`

### Lab 8 - Apache Spark Processing

Runs `spark_lab.py` with `spark-submit`.

```
Sum of Evens in 1 Million Integers: 249999500000

Word Count Top Results:
+-----------+-----+
|       word|count|
+-----------+-----+
|      spark|    3|
...
```

Result file: `results/lab08/spark_output.txt`

### Lab 9 - Spark Structured Streaming

Starts a feeder that writes one retail transaction file each second, then
runs `structured_streaming.py`. You see tables like this, one for each micro-batch:

```
-------------------------------------------
Batch: 0
-------------------------------------------
+--------------+------------------+
|       Country|   sum(TotalSpend)|
+--------------+------------------+
|United Kingdom|            1245.8|
|       Germany|             340.5|
...
```

The numbers change from run to run, because the feeder writes new files
while Spark reads them. What matters: you see one or more `Batch:` tables
with a total for each country.

Result file: `results/lab09/feeder.log`

### Lab 10 - Kafka Event Streaming

Starts ZooKeeper and Kafka (if needed), creates the topic `lab-events`, starts
the consumer, then runs the producer.

```
Listening for incoming stream events...
Received Event: 1 | Device: sensor_A | Status: NORMAL
Received Event: 2 | Device: sensor_B | Status: WARNING
Received Event: 3 | Device: sensor_A | Status: CRITICAL
```

Result file: `results/lab10/consumer.log`

## 11. Problems and solutions

**First, always do this:** in the menu, type `D` (Diagnostics). It shows what
the tool finds on your PC. It changes nothing.

| Problem | What to do |
|---|---|
| `Permission denied` when you type `./lab-runner` | Type `bash lab-runner` or `bash install.sh` again |
| `No such file or directory` | You are in the wrong folder. Type `cd ~/bda-lab` (or `cd ~/Downloads/bda-lab-main`) |
| The menu shows, but no second window opens. The lab runs in the same window | The tool did not find a graphical terminal. This is OK: the lab still runs, only in one window |
| `Lab N failed` | Press `L` in the menu, type the lab number, and read the **last** `[✗]` line. It tells you what failed |
| `... is not installed` or `... does not start` | Type `S` in the menu (Setup). It installs the tool, or replaces a damaged copy |
| The PC already has another Hadoop / Kafka and it gives errors | Nothing to do. The tool does not use it |
| `Hadoop daemons of another user are running` | Another Linux user started Hadoop on this PC. Restart the PC and run the lab again |
| The menu shows `[!] Not installed: ...` | Type `S` in the menu (Setup). Read the SETUP SUMMARY at the end |
| Setup stops at a download | Check the internet and type `S` again. The download continues from where it stopped |
| You want the lab in the same window (no second window) | Type `./lab-runner --here 5`, or set `LAB_NEW_WINDOW=0` in `config/environment.conf` |
| `Could not install numpy` (or another Python package) | Check the internet. Then run the lab again |
| A lab seems to stop for a long time | Wait. Hive and Spark need 1 to 3 minutes. Every step has a time limit, so the tool does not wait forever |
| `Port 9092 is already in use by: ...` | Another program uses this port. Close that program, or restart the PC |
| HDFS problems after you restart the PC | Only run the lab again. The tool starts HDFS by itself |

**Other copies of Hadoop, Kafka and so on**

The tool uses only its own copies in `~/bigdata_stack`. You do not have to
remove anything else from the PC, and the tool does not delete anything
outside `~/bigdata_stack`, `~/bigdata_labs` and `~/hadoopdata`.

If you really want it to use a copy that is already on the PC, write the
folder in `config/environment.conf`:

```
CFG_HADOOP_HOME="/home/cse/Desktop/hadoop-3.4.0"
CFG_JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
```

Or set `REUSE_INSTALLED=1` there: the tool then searches the PC and installs
its own copy only for tools it cannot find or that do not start.

## 12. Update, reset and uninstall

**Update to the newest version** (Option A only):

```bash
cd ~/bda-lab
git pull
```

Your settings in `config/environment.conf` stay. If `git pull` shows a
conflict in that file, type `git stash`, then `git pull`, then `git stash pop`.

**Reset** (forget which tools it found, and scan again):

```bash
rm -f ~/bda-lab/state/detected.env
```

Then start the tool and type `R`.

**Uninstall:**

```bash
rm -rf ~/bda-lab ~/bigdata_labs
rm -f ~/.local/share/applications/bigdata-lab-runner.desktop ~/Desktop/bigdata-lab-runner.desktop
```

This does not remove Java, Hadoop or any other lab software.

## 13. Command cheat sheet

```bash
cd ~/bda-lab              # go to the tool folder
./lab-runner              # open the menu
./lab-runner 5            # run Lab 5 directly
./lab-runner 4            # run Lab 4a, then Lab 4b
./lab-runner all          # run all labs, summary saved in results/last_run_summary.txt
./lab-runner setup        # install what is missing
./lab-runner --here 5     # run Lab 5 in this window (no second window)
./lab-runner diag         # check the PC only (changes nothing)
./lab-runner --help       # show these options
xdg-open results          # open the results folder
less logs/lab05.log       # read the last Lab 5 log (press q to quit)
```

---

# Part 2 - Technical reference

This part explains how the tool works inside. You do not need it to run the labs.

## Design

- **Launcher** (`lab-runner`): draws the menu, opens a lab window, then
  follows `state/lab<ID>.progress`, `.status` and `.pid`. If no terminal
  window can be opened, the lab runs in the launcher itself.
- **Lab window** (`core/labshell.sh <id>`): loads the core libraries, runs
  `labs/<lab>/run.sh` (which defines `lab_main`), writes progress and a final
  `OK`/`FAIL`, and keeps a full log in `logs/lab<ID>_<ts>.log`
  (`logs/lab<ID>.log` links to the latest).

Supported terminal emulators: gnome-terminal, xfce4-terminal, konsole,
mate-terminal, tilix, lxterminal, terminator, xterm, and
`x-terminal-emulator`. Set `TERM_EMULATOR` in the config to force one.

## Why it works on a PC that already has broken installs

Errors like "version mismatch" or "environment is not configured" on a lab
PC have four sources. Each one is removed at the root instead of patched:

| Source of the error | What the runner does |
|---|---|
| The tool on the PC is another version, half installed, or misconfigured | Never used. The runner has its own copy of every tool in `~/bigdata_stack` (versions tested together), found by a fixed path, not by searching |
| `~/.bashrc` exports (`HADOOP_HOME`, `JAVA_HOME`, `CLASSPATH`, `HADOOP_CONF_DIR`, `PATH` entries ...) | `sanitize_env` unsets all of them at the start of every lab. The runner then sets its own values and puts its own `bin` folders first in `PATH` |
| Daemons of the other copy hold the ports (NameNode on 9000, Kafka on 9092, ZooKeeper on 2181) | Stopped (they are not deleted). If they belong to another Linux user they cannot be stopped without a password: the lab then says so |
| Data written by another version (`/tmp/kafka-logs`, `/tmp/zookeeper`, HDFS name dir, Hive `metastore_db`) | The runner uses its own data directories (`~/hadoopdata`, `~/bigdata_labs/kafka-data`, `~/bigdata_labs/lab07/metastore_db`). If its own data does not load, it is removed and created again (lab data only) |

Setup starts every tool once (`hadoop version`, `pig -version`,
`hive --version`, `spark-submit --version`, `kafka-topics.sh --version`).
A copy of its own that does not start is removed and downloaded again.

Nothing needs root: Java 8 is a JDK archive unpacked into
`~/bigdata_stack/jdk8`, downloads use `curl`, `wget` or `python3` (whatever
the PC has), and `pip` is installed for the user with `get-pip.py` when
Ubuntu's python3 comes without it.

## Other repairs

| Problem | Repair |
|---|---|
| `hadoop-env.sh` has no `JAVA_HOME`, or one that points to a removed JDK | Rewrites that line (backup kept) |
| The runner's Hadoop has no configuration, or a hand-edited one | Writes a pseudo-distributed `core-site.xml`/`hdfs-site.xml` (backups kept) |
| SSH to localhost not possible | Starts the daemons with `hdfs --daemon start`. It never installs an SSH server |
| Lab window closed while HDFS runs | Daemons run in their own session (`setsid`), so closing the window does not stop them |
| NameNode never formatted | Formats once |
| NameNode stops right after starting, DataNode `Incompatible clusterIDs` | Resets the runner's HDFS data directory, formats and starts again |
| HDFS name dir belongs to another user | Uses a new data directory for this user |
| NameNode in safe mode | Waits, then leaves safe mode |
| YARN down or the job hangs | Runs the job again in local MapReduce mode |
| Output dir or HDFS file already exists | Deletes it and runs the command again |
| Pig cannot start with Hadoop 3 on `PATH` | Runs again with Pig's bundled Hadoop libraries |
| Hive guava conflict with Hadoop 3 | Swaps the guava jar (backup kept) |
| Hive local job `OutOfMemoryError` | Larger heap, small sort buffer, retry |
| Hive metastore unusable or locked | `schematool -info` check; removes and re-creates it; removes a stale Derby lock |
| Kafka broker killed, ZooKeeper still holds its registration | Waits for the old session to expire, starts the broker again (up to 3 times) |
| Kafka does not start with its old data | Removes the runner's Kafka and ZooKeeper data and starts both again |
| JVM prints `Picked up _JAVA_OPTIONS` / `JAVA_TOOL_OPTIONS` | Version detection skips that line |
| Terminal emulator cannot open a window | The lab runs in the launcher window |
| Download stalls | Dropped after 60 s without data and continued from where it stopped |
| Python module missing | `pip install --user`, then with `--break-system-packages` |
| Any command hangs | Every long command has a timeout; retries are limited by `MAX_FIX_ATTEMPTS` |

## Layout

```
bda-lab/
  lab-runner                launcher (menu, progress, "Lab N done")
  install.sh                sets permissions, adds the desktop launcher
  config/environment.conf   switches and overrides
  core/
    common.sh               output, logging, run helpers, clean environment
    terminal.sh             terminal-emulator detection and window spawning
    detect.sh               tool and Java selection, Python
    hadoop.sh               Hadoop/HDFS/YARN start and repair
    services.sh             ports, Kafka/ZooKeeper
    spark.sh                Spark
    labshell.sh             runs one lab inside its window
    setup/run.sh            installs and tests the runner's own tools
    diag/run.sh             diagnostics (read only)
  labs/lab01 ... lab10      one folder per lab: run.sh + the manual's sources and data
  logs/                     labNN_<timestamp>.log (labNN.log = latest)
  results/                  outputs of the labs, last_run_summary.txt
  state/                    progress files, detected paths, pids
```

Outside this folder the runner writes only to `~/bigdata_stack` (tools),
`~/bigdata_labs` (work files, Kafka data), `~/hadoopdata` (HDFS data),
`/tmp/retail_stream_input` (Lab 9) and pip's user folder `~/.local`.

## Configuration switches (`config/environment.conf`)

```
REUSE_INSTALLED=0         # 1 = also use copies found elsewhere on the PC
CFG_JAVA_HOME / CFG_HADOOP_HOME / CFG_PIG_HOME / CFG_HIVE_HOME / CFG_SPARK_HOME / CFG_KAFKA_HOME
STACK_DIR="$HOME/bigdata_stack"   # where Setup puts the runner's own tools
HADOOP_VER PIG_VER HIVE_VER SPARK_VER KAFKA_INSTALL_VER   # versions Setup installs
AUTO_SETUP=1              # 0 = only the S menu entry installs software
AUTO_START_SERVICES=1     # 0 = never start HDFS/YARN/Kafka
AUTO_INSTALL_PY=1         # 0 = never pip install
AUTO_WRITE_HADOOP_CONF=1  # 0 = never write core-site/hdfs-site
SERVICE_TIMEOUT=90        # seconds to wait for a service
MAX_FIX_ATTEMPTS=2        # fix-and-retry rounds per command
KAFKA_PORT=9092
TERM_EMULATOR=""          # force a terminal emulator, e.g. gnome-terminal
LAB_NEW_WINDOW=1          # 0 = run labs in the launcher window (same as --here)
LAB_RAW_OUTPUT=1          # 0 = lab window also shows [CHECK]/[STEP]/[FIX] lines
```

## Known limits

- Daemons of **another Linux user** cannot be stopped without a password.
  The lab then stops with a message that says so. Restarting the PC clears it.
- Another program (not Hadoop or Kafka) on port 9000, 9092 or 2181 is
  reported, not stopped.
- The first run needs internet and about 2 GB of downloads. The Apache
  archive server is sometimes slow (5 to 30 minutes).
- Pig 0.17 has no MapReduce mode for Hadoop 3, so Lab 5 runs `pig -x local`.
- Single machine only. Tested on Ubuntu 24.04 (x86_64). Spark 3.5 supports
  Python up to 3.12 officially; it also passed here with 3.13.

## Tested

Ubuntu 24.04, no systemd, no SSH server, as root.

- **Clean PC** (only Java 21 and Python): `./lab-runner all` installs
  everything and all 11 entries pass. Also in separate xterm and
  gnome-terminal windows; HDFS and Kafka keep running when a window closes.
- **Broken PC**: a shell with wrong `JAVA_HOME`, `HADOOP_HOME`,
  `HADOOP_CONF_DIR`, `CLASSPATH`, `HIVE_HOME`, `SPARK_HOME`, `PIG_HOME`,
  `KAFKA_HOME`; fake `hadoop`, `hive`, `pig`, `java` commands first in
  `PATH` that only print an error; a second Hadoop (NameNode + DataNode) and
  a second Kafka + ZooKeeper running on the same ports; no JDK 8; the
  runner's own Pig and Kafka copies damaged; its HDFS data and Hive
  metastore damaged. Setup and the labs repaired all of it and passed.
- Forced failures: no internet during Setup, a window closed in the middle
  of a lab, a terminal emulator that cannot start, Kafka killed with
  `kill -9`.
- Not tested: a PC where another Linux user's daemons hold the ports, ARM
  processors, Ubuntu versions other than 24.04.

## License

MIT. See [LICENSE](LICENSE).
