module DockerGen
  module Build
    class BuildStep; end

    def self.parse_build_step(definition)
      if definition.is_a? String
        return LiteralStep.new(definition)
      elsif definition.is_a?(Hash) &&
            definition.keys & ['snippet', 'vars'] == definition.keys
        return SnippetStep.new(definition)
      else
        raise DockerGen::Errors::InvalidBuildStep.new(definition.to_s)
      end
    end

    class LiteralStep < BuildStep
      attr_reader :dockerfile
      def initialize(definition)
        @dockerfile = definition
      end
    end

    class SnippetStep < BuildStep
      attr_reader :snippet
      attr_reader :vars

      def initialize(definition)
        @snippet = definition['snippet']
        @vars = definition['vars'] || {}
      end
    end
  end
end
