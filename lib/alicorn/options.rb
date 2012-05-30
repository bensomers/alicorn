require 'optparse'
require 'yaml'

module Alicorn
  class Options
    def self.parse!(daemon = false)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Alicorn is a tool for auto-scaling unicorn worker counts.
      It relies on unicorn's built-in Raindrops middleware (so make sure you have
      enabled it). It computes rough load scores based on separately averaged
      data sets. \n\nUsage: alicorn [options]"

        opts.on('-h', '--help', 'Display this screen') do
          puts opts
          exit
        end

        opts.on('--version', "version number") do
          puts Alicorn::VERSION
          exit
        end

        opts.on("--min-workers [N]", Integer, "the minimum number of workers to scale down to") do |v|
          options[:min_workers] = v
        end

        opts.on("--max-workers N", Integer, "the maximum number of workers to scale up to") do |v|
          options[:max_workers] = v
        end

        opts.on("--buffer [N]", Integer, "the number of extra workers to keep for safety's sake") do |v|
          options[:buffer] = v
        end

        opts.on("--target-ratio [F]", Float, "the desired ratio of workers to busy workers") do |v|
          options[:target_ratio] = v
        end

        opts.on("--url [URL]", String, "raindrops URL to check, defaults to 127.0.0.1/_raindrops") do |v|
          options[:url] = v
        end

        opts.on("--sample-count [N]", Integer, "number of data points to check before scaling") do |v|
          options[:sample_count] = v
        end

        opts.on("--delay [F]", Float, "delay between checks") do |v|
          options[:delay] = v
        end

        opts.on("--app-name [NAME]", String, "application name to search for in process table") do |v|
          options[:app_name] = v
        end

        opts.on("--log-path [PATH]", String, "path to write log file - leave blank for no logging") do |v|
          options[:log_path] = v
        end

        opts.on("-c", "--config PATH", String, "path for stored options - write a yaml file containing all options") do |v|
          options[:config_path] = v
        end

        opts.on("-v", "--[no-]verbose", "turn on to write profiling info") do
          options[:verbose] = true
        end

        opts.on("-d", "--[no-]dry-run", "turn on to disable actual scaling") do
          options[:dry_run] = true
        end

      end.parse!

      if options[:config_path]
        options = YAML.load_file(File.open(options[:config_path]))
        # I prefer symbol keys, but nobody ever writes yamls with symbol keys, so convert them
        options = options.inject({}) { |memo, pair| memo.store(pair.first.to_sym, pair.last); memo }
      end

      raise OptionParser::MissingArgument.new("--max-workers is a mandatory argument") unless options[:max_workers]

      options
    end
  end
end
