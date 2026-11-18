-- Create Managed Database & Table
CREATE DATABASE IF NOT EXISTS lab_hive;
USE lab_hive;

CREATE TABLE IF NOT EXISTS employee (
  emp_id INT,
  name STRING,
  dept STRING,
  salary DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- Load Data into Hive Table
LOAD DATA LOCAL INPATH '/home/hadoop/emp_data.csv' INTO TABLE employee;

-- Complex HiveQL Query with Aggregation
SELECT dept, COUNT(*) AS total_emp, AVG(salary) AS avg_sal
FROM employee
GROUP BY dept
HAVING AVG(salary) > 50000;
