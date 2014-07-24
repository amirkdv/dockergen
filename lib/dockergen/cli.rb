require 'optparse'

module DockerGen
  module CLI
    def self.init(argv)
      parser = CLI::Parser.new

      logger = Logger.new
      begin
        parser.parse!(argv)
        config = DockerGen::Build::Config.new(parser.opts, logger)
        job = DockerGen::Build::Job.new(config)
        job.generate
        return 0
      rescue  OptionParser::MissingArgument,
              OptionParser::InvalidArgument,
              OptionParser::InvalidOption => e
        logger.exception(e)
        STDERR.puts "\n#{parser.help}" unless ENV.has_key?('DOCKERGEN_DEBUG')
        return 1
      rescue  DockerGen::Errors::DockerGenError,
              Errno::ENOENT,
              Errno::EACCES => e
        logger.exception(e)
        return 1
      end
    end

    class Logger
      def warn(string)
        STDERR.puts "\033[0;33mWarning: #{string}\033[00m"
      end

      def error(string)
        STDERR.puts "\033[0;31mError: #{string}\033[00m"
      end

      def exception(e)
        error "[#{e.class}] #{e.message}"
        debug e.backtrace
      end

      def context(path, action)
        STDERR.puts "[#{action}]".ljust(15) + path
      end

      def debug(string)
        STDERR.puts string if ENV.has_key? 'DEBUG'
      end
    end

    class Parser < OptionParser
      attr_reader :opts
      def initialize(*args)
        super(args)
        @banner = "Usage: #{program_name} [options]"
        @opts = {}
        add_opt('-d [FILE]',
                '--definition',
                'Path to build definition file',
                :def_yaml)
        add_opt('-b [DIRECTORY]',
                '--build-dir',
                'Destination for docker build directory',
                :build_dir)
        add_opt('-f',
                '--force-update',
                'In case of conflict overwrite existing files in build directory',
                :force)
        on_tail('-h',
                '--help',
                'Show this usage message and exit.') { puts help ; exit }
      end

      def parse!(args)
        super(args)
        if @opts.has_key?(:def_yaml)
          d = @opts[:def_yaml]
          raise MissingArgument.new('--definition [FILE]') unless d
          raise InvalidArgument.new("cannot open '#{@opts[:def_yaml]}' to read") unless File.readable?(d)
        end
        if @opts.has_key?(:build_dir)
          b = @opts[:build_dir]
          raise MissingArgument.new('--build-dir [DIRECTORY]') unless b
          if File.exists?(b)
            raise InvalidArgument.new("A file with name #{b} already exists") unless File.directory?(b)
            raise InvalidArgument.new("cannot open build directory '#{b}' to write") unless File.writable?(b)
          else
            raise InvalidArgument.new("cannot open build directory '#{b}' to write") unless File.writable?(File.dirname(b))
          end
        end
      end

      private
      def add_opt(short_form, long_form, description, opt_key)
        on(short_form, long_form, description) { |v| @opts[opt_key] = v }
      end
    end
  end
end
