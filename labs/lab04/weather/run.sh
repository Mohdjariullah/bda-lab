#!/usr/bin/env bash
# Lab 4b - Weather Dataset Analysis, max temperature per year (manual programs)

lab_main() {
  ensure_hdfs_running || die "HDFS is not available"
  ensure_mapreduce

  lab_workdir lab04_weather
  cp "$LAB_DIR/WeatherMapper.java" "$LAB_DIR/WeatherReducer.java" "$LAB_DIR/WeatherDriver.java" "$LAB_DIR/sample_weather.txt" .
  rm -f Weather*.class weather.jar

  step 1 "Program sources"
  show "cat WeatherMapper.java"; cat WeatherMapper.java
  show "cat WeatherReducer.java"; cat WeatherReducer.java
  show "cat WeatherDriver.java"; cat WeatherDriver.java

  step 2 "Compile and build weather.jar"
  export HADOOP_CLASSPATH="$(hadoop_classpath)"
  run_as 'javac -classpath $HADOOP_CLASSPATH -d . WeatherMapper.java WeatherReducer.java WeatherDriver.java' \
    javac -classpath "$HADOOP_CLASSPATH" -d . WeatherMapper.java WeatherReducer.java WeatherDriver.java || die "Compilation failed"
  run_sh "jar cvf weather.jar Weather*.class" || die "jar failed"

  step 3 "Input file (sample_weather.txt)"
  run cat sample_weather.txt
  hdfs_cmd -mkdir -p /weather/input
  hdfs_put sample_weather.txt /weather/input/ || die "put failed"

  step 4 "Run the MapReduce job ($MR_MODE mode)"
  run_mr_job weather.jar WeatherDriver /weather/input /weather/output || die "MapReduce job failed"

  step 5 "Output (year  max temperature)"
  hdfs_cmd -cat /weather/output/part-r-00000
  hdfs_cmd -get -f /weather/output/part-r-00000 "$LAB_RESULTS/weather_output.txt"
  note_ok "Weather output: /weather/output/part-r-00000 (copy in $LAB_RESULTS/weather_output.txt)"
}
