require 'fileutils'

module DockerGen
  module Build
    class Job
      attr_reader :config
      attr_reader :steps
      attr_reader :actions

      def initialize(config)
        @config = config
        @steps = @config.definition['Dockerfile'].map do |definition|
          DockerGen::Build.parse_build_step(definition)
        end
        @required_snippets = @steps.select{|s| s.is_a?(SnippetStep)}
                                   .map{|s| s.snippet}
        @snippets = DockerGen::Build.load_snippets_by_name(@required_snippets,
                                                           @config.snippet_sources)
        @actions = @steps.flat_map do |step|
          if step.is_a? LiteralStep
            next DockerfileEntry.new("Dockerfile entry '#{step.dockerfile}'", step.dockerfile)
          elsif step.is_a? SnippetStep
            next @snippets[step.snippet].interpret(step.vars)
          else
            raise DockerGen::Errors::InvalidBuildStep.new(step.to_s)
          end
        end
      end

      public
      def generate
        if @config.build_dir
          Dir.mkdir(@config.build_dir) unless File.exists?(@config.build_dir)
        end
        @actions.select{|a| a.is_a?(ContextFile) && a.external}.each do |a|
          unless @external_files.include?(a.filename)
            msg = "no fetch rule given for context dependency '#{a.filename}' (required by #{a.source_description})"
            raise DockerGen::Errors::MissingContextFile.new(msg)
          end
        end

        dockerfile = @actions.select{|a| a.is_a?(DockerfileEntry)}
                             .map{|a| a.dockerfile}
                             .join("\n\n") + "\n"

        update_context('Dockerfile', dockerfile)
        update_context('Makefile', gen_makefile)

        @actions.select{|a| a.is_a?(ContextFile) && !a.external}
                .each{|a| update_context(a.filename, a.contents)}
      end

      def update_context(context_path, contents)
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
      def gen_makefile
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
