module DockerGen
  class Build
    attr_reader :build_def, :build_dir, :snippets, :base_dir

    def initialize(def_yaml, build_dir, base_dir, force = false)
      raise "Failed to read build configuration file '#{def_yaml}'" unless File.readable?(def_yaml)
      @base_dir = base_dir
      @build_def = YAML.load_file(def_yaml)
      DockerGen::prepare_build_dir(build_dir,force)
      @build_dir = build_dir
      load_snippets
    end

    public
      def generate
        gen_dockerfile
        DockerGen::makefile(@build_def['docker'], @build_dir, @build_def['assets'])
      end

    private
      def gen_dockerfile
        dockerfile = "FROM #{@build_def['from']}\n\n"
        @snippets.each { |s| dockerfile += s.interpret }
        dockerfile += DockerGen::wrap_comment("Final steps")
        dockerfile += "ADD . /var/build\n"
        dockerfile += "RUN chown -R root:root /var/build && chmod -R u=rw,g=r,a-rwx /var/build\n"
        dockerfile += 'CMD ["' + @build_def['cmd'].split.join('", "') + '"]' + "\n"
        DockerGen::update_file(File.join(@build_dir, 'Dockerfile'), dockerfile)
      end

      def load_snippets
        all_snippets = { }
        Dir.glob(File.join(@base_dir, 'snippets/*.yml')).each do |file|
          YAML.load_file(file).each do |snippet|
            if all_snippets[snippet['name']]
              raise "Cannot redeclare #{snippet['name']} in #{file}, previously defined in #{snippets[s['name']].path}"
            else
              vars = @build_def['vars'] || { }
              all_snippets[snippet['name']] = Snippet.new(snippet, vars, @build_dir, file)
            end
          end
          STDERR.puts "Loaded snippet defintion file #{file}"
        end
        @snippets = [ ]
        build_def['snippets'].each do |snippet|
          if all_snippets[snippet]
            @snippets << all_snippets[snippet]
          else
            raise "Undefined snippet #{snippet}"
          end
        end
      end
  end
end
