module DockerGen
  module Build

    DOCKERFILE_COMMANDS = %w[ADD COPY CMD ENTRYPOINT ENV EXPOSE MAINTAINER RUN USER VOLUME WORKDIR]
    SNIPPET_DEFINITION_ITEMS = %w[name description dockerfile context]

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

      yaml_sources.each do |source|
        YAML.load_file(source).each do |definition|
          name = definition['name']
          next unless name && names.include?(name)
          if snippets[name]
            msg = "Duplicate snippet definition for '#{name}', defined in:\n" +
                  "  - #{source}\n  - #{snippets[name].source}"
            raise DockerGen::Errors::InvalidSnippetDefinition.new(msg)
          end
          snippets[name] = Snippet.new(definition, source)
          STDERR.puts "loaded: snippet '#{name}' from #{source}" if ENV.has_key? 'DEBUG'
        end
      end
      names.each do |name|
        unless snippets.keys.include? name
          raise DockerGen::Errors::UndefinedSnippet.new("Failed to locate snippet '#{name}'")
        end
      end
      snippets
    end

    def self.check_snippet_definition(definition)
      unless definition['name']
        msg = "A snippet in #{source} does not have a name"
        raise DockerGen::Errors::InvalidSnippetDefinition.new(msg)
      end
      (definition.keys - SNIPPET_DEFINITION_ITEMS).each do |strange|
        msg = "warning: unknown snippet definition item " +
              "'#{strange}' (snippet '#{definition['name']}')"
        STDERR.puts msg
      end
      if definition['context']
        definition['context'].each do |c|
          if c['filename'].nil?
            msg = "snippet '#{definition['name']}' has a context entry without a filename"
            raise DockerGen::Errors::InvalidSnippetDefinition.new(msg)
          elsif c['filename'].index('files/') != 0 &&
                c['filename'].index('scripts/') != 0 &&
                c['contents']
            STDERR.puts "warning: snippets should place all their files in " +
                        "'files/' or 'scripts/', snippet " +
                        "'#{definition['name']}' creates '#{c['filename']}'"
          end
        end
      end
      unless definition['context'] || definition['dockerfile']
        msg = "snippet '#{definition['name']}' has no " +
              "context or dockerfile entries"
        raise DockerGen::Errors::InvalidSnippetDefinition.new(msg)
      end
      if definition['dockerfile']
        definition['dockerfile'].split("\n").each do |line|
          first = line.split()[0]
          unless line[0] =~ /\s/ || DOCKERFILE_COMMANDS.include?(first)
            msg = "warning: A dockerfile entry for snippet " +
                  "'#{definition['name']}' starts with '#{first}' " +
                  "(not a valid Dockerfile command)"
            STDERR.puts msg
          end
        end
      end
    end

    class Snippet
      attr_reader :description
      attr_reader :name
      attr_reader :dockerfile
      attr_reader :context
      attr_reader :required_vars
      attr_reader :source

      def initialize(definition, source)
        if ENV.has_key? 'DEBUG'
          STDERR.puts "initializing snippet #{definition['name']}"
        end
        Build.check_snippet_definition(definition)
        @source = source
        @description = definition['description']
        @name = definition['name']
        @dockerfile = definition['dockerfile']
        @context = definition['context'] || []
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
        @context.each {|item| item.each {|_,v| v = filter_vars(v, defined_vars)}}
        context_files = @context.map do |c|
          ContextFile.new(signature, c['filename'], c['contents'])
        end
        return context_files.push(DockerfileEntry.new(signature, @dockerfile.strip))
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
