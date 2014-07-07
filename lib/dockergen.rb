#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'yaml'

require_relative 'dockergen/build'
require_relative 'dockergen/snippet'
require_relative 'dockergen/common'

settings = {
  def_yaml: './definition.yml',
  build_dir: './build',
  base_dir: File.join(File.dirname(__FILE__), '..'),
  force: false
}

optparse = OptionParser.new do |opts|
  # --definition
  desc = "Path to build definition file (default: #{settings[:def_yaml]})"
  opts.on('-d', '--definition [file]', desc) do |def_yaml|
    unless File.exists?(def_yaml)
      STDERR.puts "dockergen: cannot access definition file #{def_yaml}: no such file"
      exit 1
    end
    unless File.readable?(def_yaml)
      STDERR.puts "dockergen: cannot access definition file #{def_yaml}: failed to read file"
      exit 1
    end
    settings[:def_yaml] = def_yaml
  end

  # --output
  desc = "Destination for docker build directory (default: #{settings[:build_dir]})"
  opts.on('-o', '--output [directory]', desc) do |build_dir|
    build_dir_parent = File.absolute_path(File.join(build_dir, '..'))
    unless File.writable?(build_dir) ||
            ( !File.exists?(build_dir) && File.writable?(build_dir_parent) )
      STDERR.puts "Failed to access/create build directory #{build_dir}"
      exit 1
    end
    settings[:build_dir] = build_dir
  end

  # --force
  desc = "overwrite existing build directory, if any (default: #{settings[:force]})"
  opts.on('-f', '--force', desc) { settings[:force] = true }
end

optparse.parse!

begin
  DockerGen::Build.new(settings[:def_yaml],
                       settings[:build_dir],
                       settings[:base_dir],
                       settings[:force]).generate
rescue Exception => e
  STDERR.puts e.message
  STDERR.puts e.backtrace if ENV['DEBUG']
  exit 1
end
