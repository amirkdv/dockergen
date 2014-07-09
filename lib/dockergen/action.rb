module DockerGen
  module Build
    class Action
      DOCKERFILE_ENTRY = 'dockerfile_entry'
      CONTEXT_FILE = 'context_file'

      attr_reader :dockerfile
      attr_reader :filename
      attr_reader :contents
      attr_reader :external
      attr_reader :type
      attr_reader :source

      def initialize(type, definition, source)
        @type = type
        @source = source
        case @type
        when DOCKERFILE_ENTRY
          @dockerfile = definition[:dockerfile]
        when CONTEXT_FILE
          @filename = definition[:filename]
          @contents = definition[:contents]
          @external = ( @contents == nil )
        else
          msg = "Invalid action type: #{@type} (from #{@source})"
          raise DockerGen::Errors::DockerGenError.new(msg)
        end
      end
    end
  end
end
