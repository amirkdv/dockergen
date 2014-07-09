module DockerGen
  module Errors
    class DockerGenError < StandardError; end
    class InvalidSnippetDefinition < DockerGenError; end
    class MissingVariable < DockerGenError; end
    class MissingContextFile < DockerGenError; end
    class InvalidBuildStep < DockerGenError; end
    class UndefinedSnippet < DockerGenError; end
  end
end
