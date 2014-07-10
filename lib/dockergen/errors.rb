module DockerGen
  module Errors
    class DockerGenError < StandardError; end
    class MissingVariable < DockerGenError; end
    class MissingContextFile < DockerGenError; end
    class UndefinedSnippet < DockerGenError; end
    class InvalidSnippetDefinition < DockerGenError; end
    class InvalidDefinitionFile < DockerGenError; end
    class InvalidBuildStep < DockerGenError; end
  end
end
