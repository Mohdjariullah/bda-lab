# Big Data Lab Runner

One launcher for all the Big Data Analytics practicals (Labs 1 to 10):
Python, HDFS, MapReduce, Pig, Hive, Spark and Kafka. (Lab 6, MongoDB, is done
on Windows: the tool only shows its script.)

You choose a lab from a menu. The tool runs every command of that lab for
you, in the correct order, in its own terminal window. When a command fails
(wrong `JAVA_HOME`, Hadoop not started, output folder already exists, and so
on), the tool shows you the error, fixes it, and runs the command again.

It is only Bash scripts. There is no `.exe` file. You start it and it shows
the output. It does not ask questions.

**It uses what is already on the PC, if it works.** Many lab PCs already have
Java, Hadoop, Hive, Pig, Spark or Kafka. The tool looks for them (first where
`HADOOP_HOME`, `JAVA_HOME` and the other variables of your shell point, then
the commands on `PATH`, then the disk), starts each one to test it, and uses
the ones that work. Nothing is downloaded for those.

**It sets up only what the lab you choose needs.** Lab 8 needs Java and
Spark, so only those are tested or downloaded. Nothing else. If something is
missing or broken it is downloaded into `~/bigdata_stack`. No password is
needed for that.

**The lab window is a plain terminal.** It shows your normal prompt, the
commands as if you typed them, and their output. No headers, no "finished"
message. Everything runs in your home folder, so the prompt is the one of a
new terminal (`student@lab-pc:~$`). At the end the window is a normal
terminal and it stays open, also when you close the menu window.

**A wrong configuration on the PC does not matter.** Errors like "version
mismatch" or "environment is not configured" come from the settings around a
tool, not from the tool. The labs run every tool with the tool's own private
settings (in `state/`), so the files and variables of the PC are not used and
not changed.

**The only time it asks for your password:** when Hadoop or Kafka was started
by *another* Linux user and blocks the lab. It then asks in the lab window, so
it can stop those processes.

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
  - [8. When it asks for your password](#8-when-it-asks-for-your-password)
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
| Internet, the first time | For the Python packages, and for any tool that is missing or broken on this PC (the tool downloads its own copy of that one) | Open any web page |
| Free disk space in your home folder | Only when something must be downloaded (all tools together: about 2 GB of downloads) | Nothing to do. Setup checks it |

You do not need to remove or repair the Hadoop or Kafka that is already on
the PC.

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

**Setup happens when you choose a lab, and only for that lab.**

| Lab | What it needs |
|---|---|
| 1, 2 | Python packages (numpy, pandas, matplotlib, seaborn) |
| 3, 4a, 4b | Java 8, Hadoop |
| 5 | Java 8, Pig |
| 6 | nothing (MongoDB is on Windows) |
| 7 | Java 8, Hadoop, Hive |
| 8, 9 | Java 8, Spark |
| 10 | Java 8, Kafka, kafka-python |

The first time you choose a lab, a Setup window opens for a moment. For each
thing in the table it does this:

1. It looks for a copy that is already on the PC.
2. It checks the version and **starts it once**. If it works, it is used:

   ```
   [✓] hadoop: the copy already on this PC works and is used: /usr/local/hadoop  (HADOOP_HOME in your shell, version 3.3.6). Nothing to download.
   ```

3. If a copy cannot be used, it says why and goes on:

   ```
   [→] hadoop: /opt/hadoop-2.7.3 (HADOOP_HOME in your shell) cannot be used: version 2.7.3, the labs need Hadoop 3.x
   ```

4. Only when no copy works, it downloads its own into `~/bigdata_stack`
   (Hadoop 3.3.6, Pig 0.17.0, Hive 3.1.3, Spark 3.5.3, Kafka 3.6.2, Java 8).

When everything is fine the Setup window closes by itself and the lab window
opens. If something could not be set up, the Setup window stays open and
shows which part and why. The next time you choose the same lab, no Setup
window opens: the lab starts at once.

To set up the tools of **all** labs in one go (for example before class),
choose **S** in the menu or type `./lab-runner setup`.

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
    S. Set up everything now (the tools of all labs)
    D. System Diagnostics
    L. View a lab log
    R. Rescan environment
   0. Exit

Enter choice:
```

**Environment status:** `[✓]` means it is set up. `[ ]` means it is not set
up yet. That is not a problem and you do not have to do anything: a lab sets
up what it needs the first time you choose it.

**To run a lab:** type its number and press **Enter**.

| You type | Result |
|---|---|
| `5` | Runs Lab 5 |
| `4a` or `4b` | Runs one part of Lab 4 |
| `4` | Runs Lab 4a, then Lab 4b |
| `A` | Runs all labs, one after the other, and shows a summary at the end |
| `S` | Sets up the tools of all labs now (not needed for one lab) |
| `D` | Checks the PC and shows a report. It changes nothing |
| `L` | Shows the full log of a lab you ran before |
| `R` | Scans the PC again (use it after you install or move a tool) |
| `0` | Closes the tool |

When you choose a lab, **a second window opens**. The lab runs in that
window. The launcher window (the first one) shows short progress lines:

```
------------------------------------------------------------
Lab 3  - Basic HDFS Commands
[→] Opened a new terminal window. Watch the commands there.
    Progress:
    [✓] Java 8: /usr/lib/jvm/java-8-openjdk-amd64
    [✓] hadoop: /usr/local/hadoop  (already on this PC, tested)
    [FIX] HDFS started (NameNode + DataNode running)
    [✓] HDFS read, write, copy and directory operations completed
    [✓] Lab 3 done
[✓] Lab 3 done  (51s)

Press ENTER to return to the Lab Runner...
```

## 7. What you see in the lab window

The lab window looks like a terminal in which you typed every command
yourself. There is your normal prompt, then the command, then what the
command printed. Nothing else: no headers, no check marks, no messages from
the tool.

```
student@lab-pc:~$ export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
student@lab-pc:~$ export PATH=$JAVA_HOME/bin:$PATH
student@lab-pc:~$ java -version
openjdk version "1.8.0_462"
student@lab-pc:~$ export SPARK_HOME=/opt/spark
student@lab-pc:~$ export PATH=$SPARK_HOME/bin:$PATH
student@lab-pc:~$ spark-submit --version
...
student@lab-pc:~$ cat spark_lab.py
...
student@lab-pc:~$ spark-submit spark_lab.py
Sum of Evens in 1 Million Integers: 249999500000
...
student@lab-pc:~$ 
```

The lab runs in your **home folder**, like in a terminal you just opened.
The program files of the lab (for example `spark_lab.py`, `WordCount.java`,
`wordcount.jar`) are created there. A file with the same name that is already
in your home folder is replaced by the lab's file.

These are the real commands, in the right order. You can copy them into your
record or type them yourself in another terminal.

The check marks and the "done" message are only in the **launcher** window.
The full story with every check is in the log file (`logs/lab08.log`). If you
want those lines in the lab window too, set `LAB_RAW_OUTPUT=0` in
`config/environment.conf`.

## 8. When it asks for your password

Almost never. The labs do not need administrator rights.

There is one case. Another Linux user (for example the account that was used
in the last class) started Hadoop or Kafka on this PC, and those programs
are still running and block the lab. Your account cannot stop the programs
of another user. Then the **lab window** shows:

```
This Hadoop daemon (pid 4711) was started by the user 'hduser' and blocks this lab.
Administrator rights are needed to stop it.
Type your Linux password and press ENTER (the letters do not show).
[sudo] password for student:
```

Type your Linux password and press **Enter**. The tool stops that program
and the lab continues. The password goes directly to `sudo` and is not saved.

If the password is not accepted, or your account may not use `sudo`, the lab
stops and says so. Restart the PC and run the lab again.

## 9. When the lab is finished

The lab window does not say "finished". After the last output you see your
prompt again, and the window is now a normal terminal:

- it is in your home folder, where the lab's files are,
- the lab's settings are active, so you can type more commands, for example
  `hdfs dfs -ls /` after Lab 3 or `spark-submit spark_lab.py` again,
- it **stays open** until you close it yourself. You can close the launcher
  (menu) window; the lab window is not affected.

The **launcher** window tells you the result:

```
[✓] Lab 5 done  (24s)
```

or, when something failed:

```
[✗] Lab 5 failed  (12s)
    What went wrong:
      - pig does not start (/opt/pig-0.17.0)
    Full log: /home/student/bda-lab/logs/lab05_20260101_101500.log
```

In the lab window a failure looks like it does in a real terminal: the
command and the error it printed. The reason in plain words is in the
launcher, under `What went wrong`.

Press **Enter** in the launcher to go back to the menu.

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
| The PC already has another Hadoop / Kafka and it gives errors | Nothing to do. Setup tests it. If it does not work, the tool downloads its own copy |
| The lab window asks for a password | Another user's Hadoop or Kafka blocks the lab. Type your Linux password (see section 8) |
| `Hadoop daemons of another user are still running` | The password was not accepted. Restart the PC and run the lab again |
| The menu shows `[ ]` next to a tool | Nothing to do. It is set up when you choose a lab that needs it |
| Setup stops at a download | Check the internet and type `S` again. The download continues from where it stopped |
| You want the lab in the same window (no second window) | Type `./lab-runner --here 5`, or set `LAB_NEW_WINDOW=0` in `config/environment.conf` |
| `Could not install numpy` (or another Python package) | Check the internet. Then run the lab again |
| A lab seems to stop for a long time | Wait. Hive and Spark need 1 to 3 minutes. Every step has a time limit, so the tool does not wait forever |
| `Port 9092 is already in use by: ...` | Another program uses this port. Close that program, or restart the PC |
| HDFS problems after you restart the PC | Only run the lab again. The tool starts HDFS by itself |

**Which copy of a tool is used**

Type `S` (Setup). The SETUP SUMMARY shows the folder of every tool. To force
a different copy, write its folder in `config/environment.conf`:

```
CFG_HADOOP_HOME="/home/cse/Desktop/hadoop-3.4.0"
CFG_JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
```

The tool never changes or deletes the copies on the PC. It writes only into
its own folder, `~/bigdata_stack`, `~/bigdata_labs` and `~/hadoopdata`.

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
./lab-runner setup        # set up the tools of ALL labs now (one lab does this for itself)
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
  (`logs/lab<ID>.log` links to the latest). It prints only command lines
  (with the user's real prompt, read from an interactive bash and expanded
  with `${PS1@P}`) and the commands' own output. When the lab is over it
  becomes an interactive shell (`exec bash --rcfile state/lab<ID>.bashrc`)
  that reads `~/.bashrc` and then sets the lab's environment again. The
  window is started in its own session, so closing the launcher does not
  close it.
- **Per-lab setup**: `lab_needs` in `core/common.sh` lists what each lab
  needs. Before a lab runs, the launcher checks only those parts and, if one
  is missing, runs Setup for those parts only.

Supported terminal emulators: gnome-terminal, xfce4-terminal, konsole,
mate-terminal, tilix, lxterminal, terminator, xterm, and
`x-terminal-emulator`. Set `TERM_EMULATOR` in the config to force one.

## How it deals with what is already on the PC

**Choosing a copy** (`core/setup/run.sh`, `candidate_homes` in `core/detect.sh`).
For each tool the candidates are, in this order: the folder in the shell
variable (`HADOOP_HOME`, `HIVE_HOME` ...), the command on `PATH`, and a disk
search under `SEARCH_ROOTS`. A candidate is taken when

1. it is a complete installation (launcher and jars),
2. its version can run the labs: Hadoop 3.x, Pig 0.16+, Hive 2.3 to 3.x,
   Spark 3.x, Kafka 2.x or 3.x with ZooKeeper, Java 8,
3. it starts: `hadoop version`, `pig -version`, `hive --version`,
   `spark-submit --version`, `kafka-topics.sh --version`, run the same way
   the labs run it.

The first one that passes is stored in `state/detected.env`. If none passes,
the runner's own copy is downloaded to `~/bigdata_stack`. A lab that finds
its tool no longer starts clears that entry; the launcher then runs Setup and
the lab again.

**Running it with private settings.** "Version mismatch" and "environment is
not configured" errors come from four places. None of them is used:

| Source of the error | What the runner does |
|---|---|
| `~/.bashrc` exports (`HADOOP_HOME`, `JAVA_HOME`, `CLASSPATH`, `HADOOP_CONF_DIR` ...) | Read once as a hint where the tools are, then unset for every lab (`sanitize_env`). The runner sets its own values and puts the chosen `bin` folders first in `PATH` |
| The tool's own configuration files (`core-site.xml` for another host, `hadoop-env.sh` with an old `JAVA_HOME`, `hive-site.xml` for MySQL, a cluster `spark-defaults.conf`) | Not used and not edited. Hadoop gets `state/hadoop-conf` (a copy plus the lab's `hdfs://localhost:9000`, local MapReduce, its own log and pid folders), Hive gets `state/hive-conf` (embedded Derby), Spark gets an empty `state/spark-conf`, Kafka gets `~/bigdata_labs/kafka-data/*.properties` |
| Folders shared by all users in `/tmp` (`/tmp/hadoop` job staging, `/tmp/kafka-logs`, `/tmp/zookeeper`) or owned by root (logs inside the installation) | Everything is redirected to `~/hadoopdata` and `~/bigdata_labs`. If the runner's own data does not load, it is removed and created again (lab data only) |
| Daemons that hold the ports: another Hadoop copy, a Hadoop that does not answer the lab's configuration, another Kafka or ZooKeeper | Stopped (nothing is deleted). Processes of this user are stopped directly. For processes of another user the lab window asks for the password (`sudo kill`) |

Nothing else needs root: a missing Java 8 is a JDK archive unpacked into
`~/bigdata_stack/jdk8`, downloads use `curl`, `wget` or `python3`, and `pip`
is installed for the user with `get-pip.py` when python3 comes without it.

## Other repairs

| Problem | Repair |
|---|---|
| SSH to localhost not possible | Starts the daemons with `hdfs --daemon start`. It never installs an SSH server |
| Lab window closed while HDFS runs | Daemons run in their own session (`setsid`), so closing the window does not stop them |
| NameNode never formatted | Formats once |
| NameNode stops right after starting, DataNode `Incompatible clusterIDs` | Resets the runner's HDFS data directory, formats and starts again |
| HDFS name dir belongs to another user | Uses a new data directory for this user |
| NameNode in safe mode | Waits, then leaves safe mode |
| YARN down or the job hangs | Runs the job again in local MapReduce mode |
| Output dir or HDFS file already exists | Deletes it and runs the command again |
| Pig cannot start with Hadoop 3 on `PATH` | Runs again with Pig's bundled Hadoop libraries |
| Hive guava conflict with Hadoop 3 | Swaps the guava jar in a Hive folder that is writable (backup kept). A read-only Hive with that conflict is not chosen by Setup |
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

Outside this folder the runner writes to:

- the home folder: the lab's own program files and outputs (`lab1_setup.py`,
  `WordCount.java`, `wordcount.jar`, `src/`, `classes/`, `pig_input/`,
  `pig_output/`, `metastore_db/`, `consumer.log` ...). With `LAB_IN_HOME=0`
  they go to `~/bigdata_labs/<lab>` instead,
- `~/bigdata_labs`: helper files that are not part of a lab (daemon logs,
  Kafka data, job staging). They never appear in the lab window,
- `~/hadoopdata` (HDFS data), `~/bigdata_stack` (downloaded tools),
  `/tmp/retail_stream_input` (Lab 9), pip's user folder `~/.local`.

Two shown commands are shortened: ZooKeeper and Kafka are shown as
`zookeeper-server-start.sh -daemon $KAFKA_HOME/config/zookeeper.properties`
and `kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties`.
They really start with the runner's copy of those two files (own data
folder, `localhost` listener).

## Configuration switches (`config/environment.conf`)

```
REUSE_INSTALLED=1         # 0 = never use the copies on the PC, always download own ones
CFG_JAVA_HOME / CFG_HADOOP_HOME / CFG_PIG_HOME / CFG_HIVE_HOME / CFG_SPARK_HOME / CFG_KAFKA_HOME
STACK_DIR="$HOME/bigdata_stack"   # where Setup puts the runner's own tools
HADOOP_VER PIG_VER HIVE_VER SPARK_VER KAFKA_INSTALL_VER   # versions Setup installs
AUTO_SETUP=1              # 0 = only the S menu entry installs software
AUTO_START_SERVICES=1     # 0 = never start HDFS/YARN/Kafka
AUTO_INSTALL_PY=1         # 0 = never pip install
SERVICE_TIMEOUT=90        # seconds to wait for a service
MAX_FIX_ATTEMPTS=2        # fix-and-retry rounds per command
KAFKA_PORT=9092
TERM_EMULATOR=""          # force a terminal emulator, e.g. gnome-terminal
LAB_IN_HOME=1             # 0 = each lab runs in ~/bigdata_labs/<lab> instead of the home folder
LAB_NEW_WINDOW=1          # 0 = run labs in the launcher window (same as --here)
LAB_RAW_OUTPUT=1          # 0 = lab window also shows [CHECK]/[STEP]/[FIX] lines
```

## Known limits

- A tool that is missing or broken needs internet once. The Apache archive
  server is sometimes slow (all five tools: 5 to 30 minutes).
- Another program (not Hadoop, Kafka or ZooKeeper) on port 9000, 9092 or
  2181 is reported, not stopped.
- Lab 9's program has the folder `/tmp/retail_stream_input` written in it.
  If another user ran Lab 9 on the same PC, that folder belongs to them.
- Pig 0.17 has no MapReduce mode for Hadoop 3, so Lab 5 runs `pig -x local`.
- Single machine only.

## Tested

- **One lab at a time on an empty PC**: Lab 8 downloaded only Java 8 and
  Spark, Lab 5 only Pig, Lab 10 only Kafka, Labs 1 and 6 nothing.
- **Lab window**: in gnome-terminal the window showed only the prompt, the
  commands and their output, ended as a working shell with the lab's
  settings, and stayed open after the launcher was closed.

Ubuntu 24.04 (x86_64), no systemd, no SSH server.

- **Tools already on the PC, unprivileged user.** Hadoop, Pig, Hive, Spark,
  Kafka and Java 8 installed system-wide and owned by root (`/opt`,
  `/usr/local`, `/usr/lib/jvm`), with wrong settings inside them (a
  `core-site.xml` for another host, `hadoop-env.sh` with a missing Java, a
  MySQL `hive-site.xml`, a cluster `spark-defaults.conf`), `/tmp/hadoop`
  owned by root, and a shell whose `HADOOP_HOME` points to an unusable Hadoop
  2.7.3. A user without any administrator rights ran `./lab-runner all`:
  Setup took 18 seconds, downloaded nothing, and all 11 entries passed.
- **Nothing on the PC** (only Java 21 and Python): everything is downloaded,
  all 11 entries pass. Also in separate xterm and gnome-terminal windows.
- **Damaged state**: the runner's own copies, HDFS data, Hive metastore and
  Kafka data damaged; a second Hadoop and Kafka running on the same ports.
  All repaired.
- **Daemons of another user**: HDFS started by root on another port. The lab
  asked for the password. With a refused password it stopped with a clear
  message. The accepted case was tested with a stand-in for `sudo`, because
  the test account could not be given real `sudo` rights.
- Not tested: a real `sudo` password typed in a real terminal, ARM
  processors, other Ubuntu versions, tool versions other than the ones above
  (for example an existing Hadoop 3.4 or Hive 2.3).

## License

MIT. See [LICENSE](LICENSE).
