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

  def self.makefile(docker_config, build_dir, assets = nil)
    # assets target
    contents = ''

    # assets target
    if ! assets.nil?
      assets_target = 'assets: '
      assets.each do |asset|
        destination = asset['destination']
        action = asset['action']
        contents += destination + ":\n\t" + action.gsub(/\n/, "\n\t") + "\n\n"
        assets_target += destination + ' '
      end
      contents += assets_target + "\n"
    end

    # build target
    contents += "\nbuild: assets\n"
    contents += "\tdocker build --tag #{docker_config['image']} .\n"

    # build_no_cache target
    contents += "\nbuild_no_cache: assets\n"
    contents += "\tdocker build --no-cache --tag #{docker_config['image']} .\n"

    # start target
    contents += "\nstart:\n\tdocker run --detach "
    contents += "--name #{docker_config['ctname']} " if docker_config['ctname']
    port_config = docker_config['ports'] || {}
    port_config.each do |port|
      contents += "--publish #{port['host']}:#{port['container']} "
    end
    contents += docker_config['image']
    contents += "\n"
    self.update_file(File.join(build_dir, 'Makefile'), contents)
  end
end
