# Big Data Lab Runner

One launcher for all the Big Data Analytics practicals (Labs 1 to 10):
Python, HDFS, MapReduce, Pig, MongoDB, Hive, Spark and Kafka.

You choose a lab from a menu. The tool runs every command of that lab for
you, in the correct order, in its own terminal window. When a command fails
(wrong `JAVA_HOME`, Hadoop not started, output folder already exists, and so
on), the tool shows you the error, fixes it, and runs the command again.

It is only Bash scripts. There is no `.exe` file. The tool never saves your
password.

```
Window 1: LAUNCHER            Window 2: LAB WINDOW              Window 3: PASSWORD WINDOW
(you type here)               (opens for each lab)              (opens only when sudo is needed)
-------------------           ----------------------------      ---------------------------------
menu + progress        --->   runs each command, shows    --->  asks for your Linux password,
"Lab 5 done"                  the error, fixes it,              then closes by itself
"Password accepted"           runs it again, shows output
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
| The lab software from your college (Java, Hadoop, Pig, Hive, Spark, Kafka, MongoDB) | The tool **finds and fixes** these. It does **not** download them | Your lab PC already has them. Step 4 shows what is found |
| Your Linux password | Only for steps that need administrator rights | The password you use to log in |
| Internet | Only to download this tool (Step 3), and to install a missing Python package | Open any web page |

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
- It does not install any software and does not change your system.

At the end it asks:

```
Open the menu now? [Y/n]
```

Press **Enter** to open the menu now.

The first start scans your PC for Java, Hadoop, Pig, Hive, Spark, Kafka and
MongoDB. This can take up to one minute. Then the menu opens (see Step 6).

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
  [✓] MongoDB
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

Some steps need administrator rights. Examples: start the MongoDB service,
install a missing Python package with `apt`, or change a file in a system
folder.

When this happens:

1. A **third window** opens with the title **ADMINISTRATOR AUTHENTICATION**:

   ```
   ============================================================
           ADMINISTRATOR AUTHENTICATION
   ============================================================

   The lab needs to run a command with sudo.
   Type your Linux password and press ENTER.
   This window closes automatically. The lab continues in its own window.

   (Press ENTER with an empty password to cancel.)

   [sudo] password for student:
   ```

2. Click inside this window.
3. Type your Linux password. **The letters do not show. This is normal.**
4. Press **Enter**.
5. The window closes. The launcher shows `[✓] Password accepted`. The lab continues.

If the password is wrong, the window opens again (attempt 2 of 3).
To cancel, press **Enter** without a password. The step then fails, and the
launcher tells you which step it was.

Safety:

- The tool does not save your password in a file.
- The password goes directly to `sudo` (the normal Linux program for administrator rights).
- After you type it once, the lab does not ask again for about 15 minutes.

Many labs do not need the password at all. Then this window does not open.

## 9. When the lab is finished

At the end of the lab window you see:

```
============================================================
 LAB 5  - APACHE PIG JAVA UDF - COMPLETED SUCCESSFULLY
============================================================
[✓] Lab 5 done
Finished: Thu Oct  1 10:15:42 EDT 2026
Full log: /home/student/bda-lab/logs/lab05_20261001_101520.log

Press ENTER to close this window...
```

Press **Enter** to close the lab window. The launcher also shows `Lab 5 done`.
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

Starts MongoDB (if needed) and runs `lab6_mongodb.js`: insert, find, update,
aggregate, delete. At the end only the Laptop is left, with the new price and
the `sale` tag:

```
{
  _id: 1,
  item: 'Laptop',
  price: 1150,
  tags: [ 'electronics', 'computers', 'tech', 'sale' ],
  ratings: [ 5, 4, 5 ]
}
```

Result file: `results/lab06/products.json`

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
| The tool uses the wrong Hadoop (your PC has two copies) | See "Choose the correct copy" below |
| `Pig is not installed` / `Hive is not installed` / `Hadoop not found` | The tool searched your PC and did not find it. Ask the lab assistant where it is installed, then see "Choose the correct copy" below |
| `No MongoDB package is available` | MongoDB is not installed on this PC. Ask the lab assistant |
| `Authentication failed or cancelled` | The password was wrong 3 times, or you cancelled. Run the lab again |
| `student is not in the sudoers file` | Your account cannot use `sudo`. Labs that do not need `sudo` still work. Ask the lab assistant for the other labs |
| `Could not install numpy` (or another Python package) | Check the internet. Then run the lab again |
| A lab seems to stop for a long time | Wait. Hive and Spark need 1 to 3 minutes. Every step has a time limit, so the tool does not wait forever |
| `Port 9092 is already in use by: ...` | Another program uses this port. Close that program, or restart the PC |
| HDFS problems after you restart the PC | Only run the lab again. The tool starts HDFS by itself |

**Choose the correct copy of a tool**

Some lab PCs have two copies of Hadoop (for example one in `/opt` and one on
the Desktop). The tool uses the newest version. To force a copy:

1. Open the config file:

   ```bash
   nano ~/bda-lab/config/environment.conf
   ```

2. Find the line for the tool and write the folder between the quotes. Example:

   ```
   CFG_HADOOP_HOME="/home/cse/Desktop/hadoop-3.4.0"
   CFG_JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
   ```

   Write the main folder of the tool (the folder that contains `bin`), not the `bin` folder.

3. Press **Ctrl + O**, **Enter** (save), then **Ctrl + X** (close).
4. Start the tool and type `R` (Rescan).

**Ask for help**

If a lab still fails, send the log file to the person who helps you. The log
is in `~/bda-lab/logs/labNN.log` (for example `lab05.log`). It contains every
command and every error.

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
./lab-runner all          # run all labs
./lab-runner diag         # check the PC only (changes nothing)
./lab-runner --help       # show these options
xdg-open results          # open the results folder
less logs/lab05.log       # read the last Lab 5 log (press q to quit)
```

---

# Part 2 - Technical reference

This part explains how the tool works inside. You do not need it to run the labs.

## Design

Three roles, three windows, no blocking between them.

- **Launcher** (`lab-runner`): draws the menu, spawns a lab window, then
  polls `state/lab<ID>.progress`, `.status` and `.pid`. It never waits on the
  lab process itself, because a spawned terminal detaches from its parent.
  Progress lines that the lab writes appear in the launcher within half a second.
  If no graphical terminal is available, the lab runs inline in the launcher.
- **Lab window** (`core/labshell.sh <id>`): sources the core libraries, runs
  `labs/<lab>/run.sh` (which defines `lab_main`), writes progress and a final
  `OK`/`FAIL` status, and keeps a full log in `logs/lab<ID>_<ts>.log`
  (`logs/lab<ID>.log` links to the latest).
- **Auth window** (`core/askpass-ui.sh`): opened only by `sudo`, through the
  `SUDO_ASKPASS` mechanism, when a step needs root.

Supported terminal emulators: gnome-terminal, xfce4-terminal, konsole,
mate-terminal, tilix, lxterminal, terminator, xterm, and
`x-terminal-emulator`. Set `TERM_EMULATOR` in the config to force one.

## The three-terminal sudo flow

The runner never reads, stores or guesses a password.

1. A lab step calls `ensure_sudo`, which runs `sudo -A -v`.
2. `sudo` runs the program in `SUDO_ASKPASS`, which is `core/askpass.sh`.
3. `askpass.sh` makes a private FIFO in `state/` (mode 600, memory only),
   then spawns the auth window (`askpass-ui.sh`) pointed at that FIFO.
4. The user types the password in the auth window. It is written once into
   the FIFO and the window closes.
5. `askpass.sh` reads the one line from the FIFO, prints it to `sudo` on
   stdout, and deletes the FIFO. `sudo` verifies it.
6. `sudo` caches the credential for the lab terminal (the usual 15 minutes).
   A background `sudo -n -v` keepalive refreshes it, so long labs do not ask
   twice. The launcher prints `Password accepted`.

Safety details: the FIFO read has a 300 second timeout; an empty password
sends a `__CANCEL__` token so `sudo` fails cleanly; `HUP`/`INT`/`TERM` traps
in both scripts prevent hangs; without a graphical session the prompt falls
back to `/dev/tty`. A wrong password makes `sudo` call askpass again, which
reopens the auth window (up to `sudo`'s limit of 3 attempts).

## "Run first, show the error, fix, run again"

Every check follows the same pattern:

1. Run the plain command the way a student types it (`java -version`,
   `hadoop version`, `pig -version`, `hdfs dfs -ls`).
2. Resolve the correct installation or setting (see below).
3. Export the variables, print the exact `export` lines, prepend `PATH`.
4. Run the command again through the absolute path of the chosen install.

`run_fix FIXFN CMD` generalises this for any command: run, and on failure call
a fix function, then run again, at most `MAX_FIX_ATTEMPTS` times.

## Tool selection (multiple copies, hard-coded paths)

For every tool (`hadoop`, `pig`, `hive`, `spark`, `kafka`) the resolver in
`core/detect.sh` picks exactly one installation. First valid source wins:

1. `CFG_<TOOL>_HOME` from `config/environment.conf` (manual override).
2. `DETECTED_<TOOL>_HOME` cached in `state/detected.env` (an earlier choice).
3. `<TOOL>_HOME` from the shell, only if it points to a real install.
4. The executable on `PATH`.
5. A filesystem search under `SEARCH_ROOTS` (`$HOME /home /opt /usr/local /usr/lib /usr/share`).

A "real install" has the launcher **and** the tool's jars, so a pip or npm
shim in `/usr/local/bin` is rejected. With several copies, the highest version
wins; ties go to the newest file. Tools always run through the absolute path
of the chosen copy, so another copy earlier on `PATH` cannot take over. The
choice is cached and printed as the `export` lines that were applied.

Java uses a version preference per lab: Hadoop, Pig and Hive prefer Java 8;
Spark 4 and Kafka 4 prefer Java 17. `list_javas` finds every JDK under
`/usr/lib/jvm`, on `PATH`, in `JAVA_HOME` and under the search roots.
Spark and Kafka accept a JRE; labs that compile Java require `javac`.

## What it detects and repairs

| Problem | What the runner does |
|---|---|
| `JAVA_HOME` wrong or unset | Lists every JDK, picks the version the tool needs, exports it |
| `HADOOP_HOME` missing or broken | Searches the roots, uses the highest version, caches the choice |
| Several copies of a tool | Highest version wins; runs through the absolute path so `PATH` cannot interfere |
| `HADOOP_CONF_DIR` points to a non-config dir | Falls back to `etc/hadoop`, then `conf`, and says so |
| `hadoop-env.sh` has an invalid `JAVA_HOME` | Rewrites that line (backup kept) |
| `hdfs dfs` says `Unknown command: dfs` | Switches to `hadoop fs` for that machine |
| `fs.defaultFS` not set | Writes a pseudo-distributed `core-site.xml`/`hdfs-site.xml` (backups kept) |
| `fs.defaultFS` host does not resolve (hostname changed) | Rewrites the host to `localhost` (backup kept) |
| A NameNode from another Hadoop copy is running | Stops those daemons, starts the selected copy |
| NameNode name dir not writable | Repoints name/data dirs to `HADOOP_DATA_DIR`, or stops with a clear message when it belongs to another user |
| SSH to localhost denied | Creates a key and `authorized_keys`; if SSH still fails, starts daemons with `hdfs --daemon start` (no SSH needed) |
| NameNode never formatted | Formats once (only when the name dir is empty) |
| DataNode `Incompatible clusterIDs` | Clears the DataNode storage dir and restarts it |
| NameNode in safe mode | Waits, then leaves safe mode |
| HDFS `Permission denied` (not the HDFS superuser) | Runs the operation again with `HADOOP_USER_NAME` set to the superuser (simple auth) |
| YARN down, MRAppMaster missing, or the job hangs | Runs the job again in local MapReduce mode through a private `HADOOP_CONF_DIR` copy (never edits your config) |
| Output dir or HDFS file already exists | Deletes it before the command runs again |
| Pig UDF: `WritableComparable not found` | Adds `hadoop-common` jars to the compile classpath |
| Pig cannot start with the installed Hadoop 3 | Runs again with `HADOOP_HOME` hidden so Pig uses its bundled libraries |
| Hive guava conflict with Hadoop 3 | Swaps the guava jar (backup kept; auth window if the dir is read-only) |
| Hive local job `OutOfMemoryError` / return code 2 | Runs Hive with a larger `HADOOP_HEAPSIZE` and a small `io.sort.mb`, then doubles the heap and retries |
| Hive metastore not initialised, stale Derby lock, pinned Derby path | `schematool -initSchema`; removes `db.lck` only when no Hive process runs; honours a `hive-site.xml` database path |
| Hive 4 (`hive` is Beeline) | Runs the same scripts through embedded HiveServer2 (`beeline -u jdbc:hive2://`) |
| MongoDB not running | `systemctl start mongod`, or a local `mongod --fork` with a private socket dir |
| Kafka: ZooKeeper or KRaft, storage not formatted, `InconsistentClusterIdException` | Detects the mode, formats storage, clears the stale log dir, reuses a broker that is already up |
| A port is held by an earlier run of this tool | Stops only that stale helper; anything else is reported and the lab stops |
| Spark missing | Uses the pip `pyspark` distribution, installs it when allowed |
| Python module missing | `pip --user`, then `--break-system-packages`, then `apt` through the auth window |
| Any command hangs | Every long command has a timeout; fixes retry at most `MAX_FIX_ATTEMPTS` times |

## Loop and hang protection

- Every service wait and every long command runs under `timeout`.
- `run_fix` and the per-lab retry loops are bounded by `MAX_FIX_ATTEMPTS`
  (default 2). No fix can loop forever.
- Background helpers (feeders, brokers, the sudo keepalive) are tracked and
  stopped when the lab ends.

## Layout

```
bda-lab/
  lab-runner                launcher (menu, progress, "Lab N done")
  install.sh                sets permissions, adds the desktop launcher
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

## Configuration switches (`config/environment.conf`)

```
CFG_JAVA_HOME / CFG_HADOOP_HOME / CFG_PIG_HOME / CFG_HIVE_HOME / CFG_SPARK_HOME / CFG_KAFKA_HOME
SEARCH_ROOTS="$HOME /home /opt /usr/local /usr/lib /usr/share"
AUTO_START_SERVICES=1     # 0 = never start HDFS/YARN/Mongo/Kafka
AUTO_INSTALL_PY=1         # 0 = never pip/apt install
AUTO_WRITE_HADOOP_CONF=1  # 0 = never write core-site/hdfs-site
SERVICE_TIMEOUT=90        # seconds to wait for a service
MAX_FIX_ATTEMPTS=2        # fix-and-retry rounds per command
KAFKA_PORT=9092
TERM_EMULATOR=""          # force a terminal emulator, e.g. gnome-terminal
```

## Known limits

- Pig 0.17 has no MapReduce mode for Hadoop 3. The runner uses HDFS paths and
  MapReduce mode only when a `pig-*-core-h3.jar` build exists; otherwise it runs
  `pig -x local` with local paths, which is what the lab machines use.
- Hive 4 runs through Beeline embedded mode. Its default engine is Tez; if Tez
  is absent, jobs may fail there. Hive 2.x and 3.x (the usual lab installs)
  use the MapReduce engine and work as-is.
- Single machine (pseudo-distributed) only. Multi-node clusters are out of scope.
- If `sudo` is missing or the user is not a sudoer, root steps are reported as
  failed with a clear message; everything else still runs.
- The tool does not download Hadoop, Hive, Pig, Spark, Kafka or MongoDB.
  It finds, configures, starts and repairs them.

## Tested

On Ubuntu 24.04 with Hadoop 3.3.6, Pig 0.17.0, Hive 3.1.3, Kafka 3.9.0,
MongoDB 8.0.4, PySpark, and Java 8 and 17 side by side: all 11 lab entries
pass in `./lab-runner all`. The three-window flow (launcher, lab window,
auth window) and the wrong-password retry were tested with a real X display
and a non-root sudo user.

## License

MIT. See [LICENSE](LICENSE).
