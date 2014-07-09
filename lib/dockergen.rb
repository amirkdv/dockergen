#!/usr/bin/env ruby

require_relative 'dockergen/job'
require_relative 'dockergen/snippets'
require_relative 'dockergen/config'
require_relative 'dockergen/cli'
require_relative 'dockergen/errors'
require_relative 'dockergen/action'
require_relative 'dockergen/step'

exit DockerGen::CLI.init(ARGV)
