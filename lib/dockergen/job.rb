require 'fileutils'

module DockerGen
  module Build
    class Job
      attr_reader :config, :actions

      def initialize(config)
        @config = config
        @components = []
        @actions = config.definition['Dockerfile'].flat_map do |item|
          if item.is_a? String
            action_def = {dockerfile: item}
            action_source = "Dockerfile entry #{item}"
            next Action.new(Action::DOCKERFILE_ENTRY, action_def, action_source)
          elsif item.is_a? Hash
            keys = item.keys
            unless keys & ['snippet', 'vars'] == keys
              raise DockerGen::Errors::InvalidBuildStep.new(item.to_s)
            end
            name = item['snippet']
            unless @config.snippets.keys.include? name
              msg = "Failed to locate snippet '#{name}'"
              raise DockerGen::Errors::InvalidBuildStep.new(msg)
            end
            next @config.snippets[name].interpret(item['vars'] || {})
          else
            raise DockerGen::Errors::InvalidComponentDefinition.new(item.to_s)
          end
        end
      end

      public
      def generate
        @actions.select{|a| a.external}.each do |action|
          filename = action.filename
          provided_files = @config.definition['assets'].map{|i| i['filename']}
          unless provided_files.include?(filename)
            msg = "no fetch rule given for file '#{filename}' (required by #{action.source})"
            raise DockerGen::Errors::MissingContextFile.new(msg)
          end
        end
        update_file('Dockerfile', dockerfile)
        update_file('Makefile', makefile)
      end

      def update_file(context_path, contents)
        path = File.join(@config.build_dir, context_path)
        write = false
        if File.exists?(path)
          if File.open(path, 'r') { |f| f.read == contents }
            STDERR.puts "[no-change]    #{path}"
          elsif @config.force_update
            STDERR.puts "[update]       #{path}"
            write = true
          else
            STDERR.puts "[out-of-date]  #{path} (use --force-update to overwrite)"
          end
        else
          STDERR.puts "[created]      #{path}"
          write = true
        end
        if write
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, 'w') { |fw| fw.write(contents) }
        end
      end

      private
      def dockerfile
        @actions.map do |action|
          case action.type
          when Action::DOCKERFILE_ENTRY
            next action.dockerfile
          when Action::CONTEXT_FILE
            update_file(action.filename, action.contents) unless action.external
          end
        end.join("\n\n").gsub!(/\n\n+/, "\n\n")
      end

      def makefile
        raise "No name specified for the generated docker image" unless @config.definition['docker_opts']['build_tag']
        # assets target
        contents = ''

        # assets target
        assets = config.definition['assets'] || []
        assets_target = 'assets: '
        assets.each do |asset|
          destination = asset['filename']
          action = asset['fetch']
          contents += destination + ":\n\t" + action.gsub(/\n/, "\n\t") + "\n\n"
          assets_target += destination + ' '
        end
        contents += assets_target + "\n"

        # build target
        tag = @config.definition['docker_opts']['build_tag']
        contents += "\nbuild: assets\n"
        contents += "\tdocker build --tag #{tag} .\n"

        # build_no_cache target
        contents += "\nbuild_no_cache: assets\n"
        contents += "\tdocker build --no-cache --tag #{tag} .\n"

        # start target
        docker_run_opts = @config.definition['docker_opts']['run_opts'] || []
        contents += "\nstart:\n\tdocker run #{docker_run_opts.join(' ')} #{tag}\n"
      end
    end
  end
end
