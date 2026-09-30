-- Registering and Running UDF in Hive
ADD JAR /path/to/MaskSalaryUDF.jar;
CREATE TEMPORARY FUNCTION mask_sal AS 'com.lab.hive.MaskSalaryUDF';
SELECT name, mask_sal(CAST(salary AS STRING)) FROM employee;
