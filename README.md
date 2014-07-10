What is it?
==========
`dockergen` is a tool that facilitates code reuse in provisioning docker
containers. It allows you to define docker build directories using predefined
tested components. Each unit of code reuse (called a _snippet_) defines the
following:

- Dockerfile commands,
- Context dependencies: snippets may expect certain files to exist in the build
  context. They have the option of providing its contents or allow them to be
  fetched from external sources (e.g. database dumps).
- documentation: each snippet has a description that can be of any length and is
  included in the appropriate section in the generated Dockerfile.

Each invocation of `dockergen` requires a build defintion file (again in YAML
format) which contains the following (see
[`definition.example.yml`](definition.example.yml)):

- paths to files or directories where referenced snippets are to be found,
- a sequence of snippets or literal Dockerfile commands,
- fetch rules for context dependencies that snippets declare but do not provide
  contents for (e.g. database dumps, CVS repos)
- docker automation configuration: docker run options, built image tag, etc.

The output of `dockergen` is a docker build directory containing at least a
`Dockerfile` and a `Makefile` with a `build`, `start`, and `assets` targets (see
the [output](example) build directory as defined
by [`definition.example.yaml`](definition.example.yml)).

Snippets
========

Here is a possible definition for the `initialize_apt` snippet used above:
```yaml
- name: initialize_apt
  description: configure apt and install apt-add-repository
  dockerfile: |
    ENV DEBIAN_FRONTEND noninteractive
    RUN apt-get update && apt-get install -y python-software-properties
```
which translates to the following in the generated `Dockerfile`:
```bash
#===============================================================================
# configure apt and install apt-add-repository
#===============================================================================
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y python-software-properties
```

Spec
----
Each snippet can define the following:

- `name` (mandatory, used as identifier for the snippet)
- `description` (recommended as otherwise the Dockefile entry would have no comments)
- `dockerfile` (optional): A string that is filtered through for [variables](#variables)
  and dumped into the resulting Dockefile
- `context`: a list of dependencies each containing
  - `filename` (mandatory): relative path, within the build context, of a
    file that the snippet expects to exist.
  - `contents` (optional): the contents of the given dependency. If not
    provided, the [build definition](#build-definition) must provide a method of
    fetching this file.

Variables
---------
Every string value in a snippet definition is subject to variable interpolation
,that is `dockerfile` entries as well as `filename` and `contents` in `context`
entries.  To define a variable anywhere in a snippet use `%%var_name%%`. For
example, the following snippet defines the variable `admin_email`:
```yaml
- name: X
  dockerfile: echo "ADMIN_EMAIL=%%admin_email%%" >> /etc/defaults/X
```
When a snippet is included in the build definition, all its variables must be
defined:
```yaml
Dockerfile:
  - FROM ubuntu:12.04
  - snippet: X
    vars:
      admin_email: admin@example.com
```

Example Snippet
---------------
The following is an example definition of a snippet that installs and configures
Apache under supervisor control:
```yaml
- name: apache2
  description: install Apache and configure it under supervisor control
  dockerfile: |
    RUN apt-get install -y apache2
    RUN rm /etc/apache2/sites-enabled/*
    ADD files/supervisor/apache.conf /etc/supervisor/conf.d/apache.conf
    RUN sed -i 's/Listen 80/Listen %%listen_ports%%/' /etc/apache2/ports.conf
    RUN a2enmod %%mods%%
  context:
  - filename: files/supervisor/apache.conf
    contents: |
      ; supervisor configuration for Apache
      [program:apache]
      command = /bin/sh -c '. /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND'
```
And here is a proper usage of the snippet in the build definition:
```yaml
Dockerfile:
  - FROM ubuntu:12.04
  - ... # truncated
  - snippet: apache2
    vars:
      listen_ports: 80
      mods: rewrite
  - ... # truncated
```

Guidelines
----------
For better readability and maintainability, you should try and follow these
guidelines. Dockergen does not enforce any but issues a warning when it catches
a violation:
1. Snippets should create their context dependencies under the following
   subdirectories of the build context (`filename` in each `context` entry):
   1. `files/` or `scripts/` if the snippet is providing the contents of the
      file,
   2. `assets/` if this is an external dependency for which the build definition
      must provide a `fetch` rule.
1. Typically snippets want to upload a file from the context to the image. In
   such cases, as much as possible try and use a path under `/var/build` for the
   uploaded files. For example, if your snippet adds a script and executes it in
   the dockerfile use `ADD scripts/[name] /var/build/scripts/[name]`.
1. Use all lower case snake case for snippet names. Try to order the terms in
   decreasing order of informativeness, e.g. `mysql_load_dump` is better than
   `load_mysql_dump`.
1. Dockergen is smart about updating files in the build directory to avoid
   unnecessarily disvalidating docker caches. To make the most out of this
   feature make sure your snippet `ADD`s its dependencies as late as possible.
1. Since `filename`s in context dependencies can also contain variables. If you
   decide to use this feature, use `context_[varname]` to indicate that the path
   is relative to the build context and not a path in the built image.
1. Dockergen does not perform *any* dependency management. If you snippet makes
   as an assumption about existing files try and write its Dockerfile commands
   in such a way that they would fail if your assumptions about satisfied
   dependencies are false.

Demo
====

The example defintion file (`definition.example.yml`) installs and configures
Apache under Supervisor and creates a `Hello World` Apache site served on port
8001 of the docker host.

* First:

        git clone http://github.com/amirkdv/dockergen
        cd dockergen

* Generate the docker build directory:

        bin/dockergen --definition definition.example.yml --build-dir apache_app_build
        # [created]      apache_app_build/files/supervisor/supervisord.conf
        # [created]      apache_app_build/files/supervisor/apache.conf
        # [created]      apache_app_build/files/apache_vhost
        # [created]      apache_app_build/Dockerfile
        # [created]      apache_app_build/Makefile

  This will create the direcory `apache_app_build` with the following contents:

      tree apache_app_build/
      # apache_app_build/
      # |-- Dockerfile
      # |-- files
      # |   |-- apache_vhost
      # |   `-- supervisor
      # |       |-- apache.conf
      # |       `-- supervisord.conf
      # `-- Makefile

* Build the docker image using the prepopulated `make build` target:

        make -C apache_app_build/ build
        # mkdir -p assets/site && echo 'Hello World' > assets/site/index.html
        # docker build --tag apache_app .
        # ... [docker build logs]
        # Successfully built cda5f6b6bb4d

  Note that the prerequisite `assets` target is responsible for creating the
  dependency of the `apache_2.2_site` snippet on the directory `assets/site` to
  exist in the context. The following is the directory structure after `make build`:

      tree apache_app_build/
      # apache_app_build/
      # |-- assets
      # |   `-- site
      # |       `-- index.html
      # |-- Dockerfile
      # |-- files
      # |   |-- apache_vhost
      # |   `-- supervisor
      # |       |-- apache.conf
      # |       `-- supervisord.conf
      # `-- Makefile

* Start the docker container:

        make -C apache_app_build/ start
        # docker run --name ct_apache_app --publish 8001:80 amirkdv/apache_app
        # 2014-07-09 17:06:53,391 CRIT Supervisor running as root (no user in config file)
        # 2014-07-09 17:06:53,391 WARN Included extra file "/etc/supervisor/conf.d/apache.conf" during parsing
        # 2014-07-09 17:06:53,426 INFO RPC interface 'supervisor' initialized
        # 2014-07-09 17:06:53,427 CRIT Server 'unix_http_server' running without any HTTP authentication checking
        # 2014-07-09 17:06:53,428 INFO supervisord started with pid 1
        # 2014-07-09 17:06:54,431 INFO spawned: 'apache' with pid 10
        # 2014-07-09 17:06:55,454 INFO success: apache entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)

* Use the container:

        curl localhost:8001
        # Hello World
