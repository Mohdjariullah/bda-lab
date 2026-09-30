import java.io.IOException;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

public class WeatherMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
    @Override
    public void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
        String line = value.toString();
        if (line.length() >= 15) {
            String year = line.substring(0, 4);
            int temp = Integer.parseInt(line.substring(5, 10).trim());
            context.write(new Text(year), new IntWritable(temp));
        }
    }
}
