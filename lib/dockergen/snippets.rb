module DockerGen
  module Build
    def self.load_snippets(source_dir)
      failure_msg = "Failed to load snippets from #{source_dir}"
      unless File.directory?(source_dir)
        raise "#{failure_msg}: no such directory"
      end
      unless File.readable?(source_dir)
        raise "#{failure_msg}: cannot open directory"
      end
      snippets = {}
      Dir.glob(File.join(source_dir, '*.yml')).each do |source_file|
        YAML.load_file(source_file).each do |definition|
          unless definition['name']
            raise "Cannot have a snippet without a name, in #{source_file}"
          end
          name = definition['name']
          if snippets[name]
            raise "Cannot redeclare #{definition['name']}, in #{source_file}"
          end
          snippets[name] = Snippet.new(definition)
        end
        STDERR.puts "loaded: #{source_file}" if ENV.has_key? 'DEBUG'
      end
      snippets
    end

    class Snippet
      attr_reader :description
      attr_reader :name
      attr_reader :dockerfile
      attr_reader :context
      attr_reader :required_vars

      def initialize(definition)
        @description = definition['description']
        @name = definition['name']
        STDERR.puts "initializing snippet #{@name}" if ENV.has_key? 'DEBUG'
        @dockerfile = definition['dockerfile']
        @context = definition['context'] || []
        unless @context.is_a? Array
          msg = "context must be an array, #{@context.class} given for #{signature}"
          raise DockerGen::InvalidSnippetDefinition.new()
        end
        scan_list = @dockerfile ? [ @dockerfile ] : []
        @context.each { |item| item.each { |k,v| scan_list << v } }
        @required_vars = scan_list.map do |string|
          string.scan(/%%([^%]+)%%/)
        end.flatten(2).uniq
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
        return @context.map do |c|
          action_def = {filename: c['filename'], contents: c['contents']}
          Action.new(Action::CONTEXT_FILE, action_def, signature)
        end.push(dockerfile_entry)
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
