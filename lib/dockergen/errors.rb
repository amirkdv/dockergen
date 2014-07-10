module DockerGen
  module Errors
    class DockerGenError < StandardError; end
    class InvalidSnippetDefinition < DockerGenError; end
    class MissingVariable < DockerGenError; end
    class MissingContextFile < DockerGenError; end
    class InvalidBuildStep < DockerGenError; end
    class UndefinedSnippet < DockerGenError; end
    class InvalidActionDefinition < DockerGenError; end
    class InvalidDefinitionFile < DockerGenError; end
  end
end
