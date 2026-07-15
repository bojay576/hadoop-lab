import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

import java.io.IOException;

/**
 * 电商日志分析 MapReduce 作业
 *
 * 输入格式: timestamp\tuser_id\tproduct_id\taction\tcategory\tduration_sec
 *
 * 分析内容 (通过命令行参数选择):
 *   pv-uv        : 统计每日 PV 和 UV
 *   top-products : 热门商品排行 (按访问次数)
 *   action-dist  : 用户行为分布统计
 *   category-dist: 商品类目分布统计
 */
public class LogAnalyzer extends Configured implements Tool {

    // ==================== PV/UV 分析 ====================
    public static class PVMapper extends Mapper<LongWritable, Text, Text, Text> {
        private Text dateKey = new Text();
        private Text value = new Text();

        @Override
        protected void map(LongWritable key, Text line, Context context) throws IOException, InterruptedException {
            String[] fields = line.toString().split("\t");
            if (fields.length < 6) return;

            String timestamp = fields[0];  // "2026-07-10 14:30:00"
            String userId = fields[1];

            // 提取日期
            String date = timestamp.split(" ")[0];
            dateKey.set(date);

            // 输出两种值: PV 计数和 UV 用户ID
            context.write(dateKey, new Text("pv\t1"));
            context.write(dateKey, new Text("uv\t" + userId));
        }
    }

    public static class PVReducer extends Reducer<Text, Text, Text, Text> {
        @Override
        protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
            int pv = 0;
            java.util.Set<String> uniqueUsers = new java.util.HashSet<>();

            for (Text val : values) {
                String[] parts = val.toString().split("\t");
                if (parts[0].equals("pv")) {
                    pv++;
                } else if (parts[0].equals("uv")) {
                    uniqueUsers.add(parts[1]);
                }
            }
            context.write(key, new Text("PV=" + pv + "\tUV=" + uniqueUsers.size()));
        }
    }

    // ==================== 热门商品分析 ====================
    public static class ProductMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
        private Text productKey = new Text();
        private final IntWritable one = new IntWritable(1);

        @Override
        protected void map(LongWritable key, Text line, Context context) throws IOException, InterruptedException {
            String[] fields = line.toString().split("\t");
            if (fields.length < 6) return;

            String productId = fields[2];
            String action = fields[3];

            // 统计非搜索行为的商品访问
            if (!"search".equals(action)) {
                productKey.set(productId);
                context.write(productKey, one);
            }
        }
    }

    public static class ProductReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
        @Override
        protected void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            context.write(key, new IntWritable(sum));
        }
    }

    // ==================== 行为分布分析 ====================
    public static class ActionMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
        private Text actionKey = new Text();
        private final IntWritable one = new IntWritable(1);

        @Override
        protected void map(LongWritable key, Text line, Context context) throws IOException, InterruptedException {
            String[] fields = line.toString().split("\t");
            if (fields.length < 6) return;

            actionKey.set(fields[3]);
            context.write(actionKey, one);
        }
    }

    // ==================== 类目分布分析 ====================
    public static class CategoryMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
        private Text categoryKey = new Text();
        private final IntWritable one = new IntWritable(1);

        @Override
        protected void map(LongWritable key, Text line, Context context) throws IOException, InterruptedException {
            String[] fields = line.toString().split("\t");
            if (fields.length < 6) return;

            categoryKey.set(fields[4]);
            context.write(categoryKey, one);
        }
    }

    @Override
    public int run(String[] args) throws Exception {
        if (args.length < 3) {
            System.err.println("用法: LogAnalyzer <analysis-type> <input-path> <output-path>");
            System.err.println("  analysis-type: pv-uv | top-products | action-dist | category-dist");
            return 1;
        }

        String analysisType = args[0];
        String inputPath = args[1];
        String outputPath = args[2];

        Configuration conf = getConf();
        Job job = Job.getInstance(conf, "LogAnalyzer - " + analysisType);
        job.setJarByClass(LogAnalyzer.class);

        FileInputFormat.addInputPath(job, new Path(inputPath));
        FileOutputFormat.setOutputPath(job, new Path(outputPath));

        switch (analysisType) {
            case "pv-uv":
                job.setMapperClass(PVMapper.class);
                job.setReducerClass(PVReducer.class);
                job.setMapOutputKeyClass(Text.class);
                job.setMapOutputValueClass(Text.class);
                job.setOutputKeyClass(Text.class);
                job.setOutputValueClass(Text.class);
                break;

            case "top-products":
                job.setMapperClass(ProductMapper.class);
                job.setReducerClass(ProductReducer.class);
                job.setMapOutputKeyClass(Text.class);
                job.setMapOutputValueClass(IntWritable.class);
                job.setOutputKeyClass(Text.class);
                job.setOutputValueClass(IntWritable.class);
                break;

            case "action-dist":
                job.setMapperClass(ActionMapper.class);
                job.setReducerClass(ProductReducer.class); // 复用 reducer
                job.setMapOutputKeyClass(Text.class);
                job.setMapOutputValueClass(IntWritable.class);
                job.setOutputKeyClass(Text.class);
                job.setOutputValueClass(IntWritable.class);
                break;

            case "category-dist":
                job.setMapperClass(CategoryMapper.class);
                job.setReducerClass(ProductReducer.class); // 复用 reducer
                job.setMapOutputKeyClass(Text.class);
                job.setMapOutputValueClass(IntWritable.class);
                job.setOutputKeyClass(Text.class);
                job.setOutputValueClass(IntWritable.class);
                break;

            default:
                System.err.println("未知分析类型: " + analysisType);
                System.err.println("可选: pv-uv | top-products | action-dist | category-dist");
                return 1;
        }

        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new LogAnalyzer(), args);
        System.exit(exitCode);
    }
}
