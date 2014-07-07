module DockerGen
  class Snippet
    attr_reader :vars, :build_dir, :base_dir, :description, :name, :steps
    def initialize(definition, build_dir, base_dir)
      @description = definition['description']
      @name = definition['name']
      if definition['steps']
        @steps = definition['steps']
      else
        raise "No steps defined for #{@name}"
      end
      @base_dir = base_dir
      @build_dir = build_dir
    end

    def interpret(vars)
      if @description
        dockerfile = DockerGen::wrap_comment(@description)
      else
        dockerfile = ''
        STDERR.puts "Description is empty for #{@name}"
      end
      @steps.each do |step|
        raise "Each step must be one of add/run/env, multiple given in #{@name}" if step.keys.count > 1
        type = step.keys[0]
        action = step[type]
        case type
        when 'add'
          dockerfile += interpret_add(action, vars) + "\n"
        when 'run'
          action = DockerGen::filter_vars(action, vars)
          action = action.strip.gsub(/\n/, "\n    ")
          dockerfile += 'RUN ' + action + "\n"
        when 'env'
          name = DockerGen::filter_vars(action['name'], vars)
          value = DockerGen::filter_vars(action['value'], vars)
          dockerfile += 'ENV ' + name + ' ' + value + "\n"
        when 'inline'
          action = DockerGen::filter_vars(action, vars)
          dockerfile += action + "\n"
        else
          raise "Unknown type '#{type}' in snippet #{@name} (file: #{@file})"
        end
      end
      dockerfile + "\n"
    end

    private
      def interpret_add(definition, vars)
        local_dst = File.join('files', definition['filename'])
        if definition['filename']
          if definition['source'] && definition['contents']
            raise "'add' blocks can either have 'source' or 'contents', both given for '#{@name}'"
          elsif definition['source']
            source = File.join(File.dirname(@base_dir), definition['source'])
            contents = File.open(source, 'r') { |f| f.read }
            contents = DockerGen::filter_vars(contents, vars)
          elsif definition['contents']
            contents = DockerGen::filter_vars(definition['contents'], vars)
          else
            raise "'add' blocks must either have 'source' or 'contents', none given for '#{@name}'"
          end
        else
          raise "'add' blocks must specify 'filename', none given for '#{@name}'"
        end
        DockerGen::update_file(File.join(@build_dir, local_dst), contents)

        "ADD #{local_dst} #{definition['destination']}"
      end

  end
end
