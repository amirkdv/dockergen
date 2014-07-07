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
      # Dockerfile and corresponding files/
      dockerfile = gen_dockerfile(@build_def['Dockerfile'])
      DockerGen::update_file(File.join(@build_dir, 'Dockerfile'), dockerfile)

      # Makefile
      assets = @build_def['assets'] || {}
      makefile = DockerGen::gen_makefile(@build_def['Makefile'])
      DockerGen::update_file(File.join(@build_dir, 'Makefile'), makefile)
    end

    private
    def gen_dockerfile(definition)
      raise "Dockerfile FROM not specified" unless definition['from']
      contents = "FROM #{definition['from']}\n\n"
      vars = definition['vars'] || {}
      @snippets.each { |s| contents += s.interpret(vars)}
      contents += DockerGen::wrap_comment("Final steps")
      contents += "ADD . /var/build\n"
      contents += "RUN chown -R root:root /var/build && chmod -R u=rw,g=r,a-rwx /var/build\n"
      if definition['cmd']
        contents += 'CMD ["' + definition['cmd'].split.join('", "') + '"]' + "\n"
      end
      return contents
    end

    def load_snippets
      all_snippets = {}
      Dir.glob(File.join(@base_dir, 'snippets/*.yml')).each do |file|
        YAML.load_file(file).each do |snippet|
          if all_snippets[snippet['name']]
            raise "Cannot redeclare #{snippet['name']} in #{file}, previously defined in #{snippets[s['name']].path}"
          else
            all_snippets[snippet['name']] = Snippet.new(snippet, @build_dir, file)
          end
        end
        STDERR.puts "Loaded snippet defintion file #{file}"
      end
      @snippets = [ ]
      build_def['Dockerfile']['snippets'].each do |snippet|
        if all_snippets[snippet]
          @snippets << all_snippets[snippet]
        else
          raise "Undefined snippet #{snippet}"
        end
      end
    end
  end
end
