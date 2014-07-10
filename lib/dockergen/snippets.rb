module DockerGen
  module Build
    def self.load_snippets_by_name(names, sources)
      snippets = {}
      yaml_sources = []
      yaml_sources = sources.flat_map do |src|
        if File.directory?(src)
          next Dir.glob(File.join(src, '*.yml' )) +
               Dir.glob(File.join(src, '*.yaml'))
        elsif File.exists?(src)
          next src
        else
          raise DockerGen::Errors::DockerGenError.new("Failed to locate snippet source '#{src}'")
        end
      end

      yaml_sources.each do |src|
        YAML.load_file(src).each do |definition|
          name = definition['name']
          next unless name && names.include?(name)
          if snippets[name]
            msg = "Cannot redeclare snippet '#{name}' in #{src} (also declared in #{snippets[name].source})"
            raise DockerGen::Errors::InvalidSnippetDefinition.new(msg)
          end
          snippets[name] = Snippet.new(definition, src)
          STDERR.puts "loaded: snippet '#{name}' from #{src}" if ENV.has_key? 'DEBUG'
        end
      end
      names.each do |name|
        unless snippets.keys.include? name
          raise DockerGen::Errors::UndefinedSnippet.new("Failed to locate snippet '#{name}'")
        end
      end
      snippets
    end

    class Snippet
      attr_reader :description
      attr_reader :name
      attr_reader :dockerfile
      attr_reader :context
      attr_reader :required_vars
      attr_reader :source

      def initialize(definition, source)
        @source = source
        @description = definition['description']
        @name = definition['name']
        STDERR.puts "initializing snippet #{@name}" if ENV.has_key? 'DEBUG'
        @dockerfile = definition['dockerfile']
        @context = definition['context'] || []
        unless @context.is_a? Array
          msg = "context must be an array, #{@context.class} given for #{signature}"
          raise DockerGen::InvalidSnippetDefinition.new()
        end
        scan_list = @context.flat_map{|item| item.values}
        scan_list << @dockerfile if @dockerfile
        @required_vars = scan_list.map{|str| str.scan(/%%([^%]+)%%/)}
                                  .flatten(2)
                                  .uniq
      end

      def interpret(defined_vars)
        @required_vars.each do |var|
          msg = "Configuration variable '#{var}' (snippet '#{@name}') is not defined"
          raise DockerGen::Errors::MissingVariable.new(msg) unless defined_vars.keys.include?(var)
        end
        @dockerfile ||= ''
        @dockerfile = filter_vars(@dockerfile, defined_vars)
        if @description
          header = '#'.ljust(80, '=')
          header = "#{header}\n#{@description.strip.gsub(/^/, '# ')}\n#{header}"
          @dockerfile = "#{header}\n#{@dockerfile}"
        else
          STDERR.puts "[warning] Description is empty for #{signature}"
        end
        @context.each { |item| item.each { |k,v| v = filter_vars(v, defined_vars) } }
        dockerfile_entry = Action.new(Action::DOCKERFILE_ENTRY,
                                      {dockerfile: @dockerfile.strip},
                                      signature)
        context_file_entries = @context.map do |c|
          Action.new(Action::CONTEXT_FILE,
                     {filename: c['filename'], contents: c['contents']},
                     signature)
        end
        return context_file_entries + [dockerfile_entry]
      end

      private
      def filter_vars(string, defined_vars)
        @required_vars.each do |var|
          string.gsub!(/%%#{var}%%/, defined_vars[var].to_s)
        end
        string
      end

      def signature
        "snippet '#{@name}'"
      end
    end
  end
end
