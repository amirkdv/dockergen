require 'yaml'

module DockerGen
  module Build
    class Config
      attr_reader :base_dir
      attr_reader :build_dir
      attr_reader :stdout
      attr_reader :force_update
      attr_reader :definition
      attr_reader :snippets

      def initialize(opts)
        opts = {
          def_yaml: File.join(Dir.getwd, 'definition.yml'),
          build_dir: File.join(Dir.getwd, 'build'),
          stdout: false,
          definition: nil,
          force: false
        }.merge(opts || {})
        @def_yaml = opts[:def_yaml]
        @stdout = opts[:stdout]
        @force_update = opts[:force]
        @build_dir = opts[:build_dir]
        @definition = YAML.load_file(@def_yaml)
        @base_dir = File.expand_path(File.dirname(@def_yaml))
        @snippets = DockerGen::Build::load_snippets(File.join(@base_dir, 'snippets'))
        prepare
      end

      def prepare()
        if @build_dir
          Dir.mkdir(@build_dir) unless File.exists?(@build_dir)
        end
      end
    end
  end
end
