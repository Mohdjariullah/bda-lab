package com.lab.pig;

import java.io.IOException;
import org.apache.pig.EvalFunc;
import org.apache.pig.data.Tuple;

public class CleanDataUDF extends EvalFunc<String> {
    @Override
    public String exec(Tuple input) throws IOException {
        if (input == null || input.size() == 0 || input.get(0) == null) {
            return null;
        }
        String str = (String) input.get(0);
        // Clean input string: remove special symbols and convert to UPPERCASE
        String cleaned = str.replaceAll("[^a-zA-Z0-9 ]", "").trim().toUpperCase();
        return cleaned.isEmpty() ? null : cleaned;
    }
}
