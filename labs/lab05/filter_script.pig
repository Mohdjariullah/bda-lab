-- Register custom JAR file
REGISTER /path/to/CleanDataUDF.jar;

-- Load Raw Data
raw_data = LOAD '/user/hadoop/pig_input/raw_logs.csv' USING PigStorage(',') AS (id:int, message:chararray);

-- Clean data using User Defined Function
cleaned_tuples = FOREACH raw_data GENERATE id, com.lab.pig.CleanDataUDF(message) AS clean_msg;

-- Filter out nulls/unwanted records
filtered_data = FILTER cleaned_tuples BY clean_msg IS NOT NULL;

-- Store Results
STORE filtered_data INTO '/user/hadoop/pig_output' USING PigStorage(',');
