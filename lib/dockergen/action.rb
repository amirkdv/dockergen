module DockerGen
  module Build
    class Action
      attr_reader :source_description
      def initialize(source_description, *args)
        @source_description = source_description
      end
    end

    class DockerfileEntry < Action
      attr_reader :dockerfile

      def initialize(*args, dockerfile)
        super(args)
        @dockerfile = dockerfile.strip
      end
    end

    class ContextFile < Action
      attr_reader :filename
      attr_reader :contents
      attr_reader :external

      def initialize(*args, filename, contents)
        super(args)
        @filename = filename
        raise DockerGen::Errors::InvalidActionDefinition unless @filename
        @contents = contents
        @external = ( @contents == nil )
      end
    end
  end
end
