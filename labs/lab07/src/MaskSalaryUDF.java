package com.lab.hive;

import org.apache.hadoop.hive.ql.exec.UDF;
import org.apache.hadoop.io.Text;

public class MaskSalaryUDF extends UDF {
    public Text evaluate(Text input) {
        if (input == null) return null;
        return new Text("XXXX-CONFIDENTIAL");
    }
}
