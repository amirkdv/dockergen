module DockerGen
  def self.filter_vars(string, vars)
    subst = { }
    string.scan(/%%([^%]+)%%/) do |var|
      var = var[0]
      if vars.has_key?(var)
        subst[var] = vars[var]
      else
        raise "Configuration parameter #{var} is not defined"
      end
    end
    subst.each { |k,v| string.gsub!(/%%#{k}%%/, v.to_s) }
    string
  end

  def self.wrap_comment(comment)
    header = '#'.ljust(80, '=')
    return "#{header}\n#{comment.strip.gsub(/^/, '# ')}\n#{header}\n"
  end

  def self.update_file(path, contents)
    unless File.exists?(path) && File.open(path, 'r') { |f| f.read == contents }
      STDERR.puts "updated file #{path}"
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |fw| fw.write(contents) }
    end
  end

  def self.prepare_build_dir(build_dir, force)
    if File.exists?(build_dir) && force
      FileUtils.rm_r(File.join(build_dir, 'files'))
      FileUtils.rm(File.join(build_dir, 'Dockerfile'))
      FileUtils.rm(File.join(build_dir, 'Makefile'))
    end
    Dir.mkdir(build_dir) unless File.exists?(build_dir)
  end

  def self.gen_makefile(definition)
    raise "No name specified for the generated docker image" unless definition['image_tag']
    # assets target
    contents = ''

    # assets target
    assets = definition['assets'] || []
    assets_target = 'assets: '
    assets.each do |asset|
      destination = asset['destination']
      action = asset['action']
      contents += destination + ":\n\t" + action.gsub(/\n/, "\n\t") + "\n\n"
      assets_target += destination + ' '
    end
    contents += assets_target + "\n"

    # build target
    contents += "\nbuild: assets\n"
    contents += "\tdocker build --tag #{definition['image_tag']} .\n"

    # build_no_cache target
    contents += "\nbuild_no_cache: assets\n"
    contents += "\tdocker build --no-cache --tag #{definition['image_tag']} .\n"

    # start target
    docker_run_opts = definition['docker_run_opts'] || []
    contents += "\nstart:\n\tdocker run #{docker_run_opts.join(' ')} #{definition['image_tag']}\n"
    return contents
  end
end
