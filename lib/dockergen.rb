#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'yaml'

require_relative 'dockergen/build'
require_relative 'dockergen/snippet'
require_relative 'dockergen/common'

def_yaml = 'definition.yml'
build_dir = 'build'
base_dir = File.join(File.dirname(__FILE__), '..')
force = false

optparse = OptionParser.new do |opts|
  opts.on('-d', '--definition [file]', 'Build definition file' ) { |f| def_yaml = f }
  opts.on('-o', '--output [directory]', 'Output docker build directory') { |f| build_dir = f }
  opts.on('-f', '--force', 'override existing build directory, if any') { force = true }
end

optparse.parse!

begin
  DockerGen::Build.new(def_yaml, build_dir, base_dir, force).generate
rescue Exception => e
  puts e.message
  puts e.backtrace if ENV['DEBUG']
  exit(1)
end
