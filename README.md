What is it?
==========
Dockergen is a tool that facilitates code reuse in provisioning docker
containers. It allows you to define docker build directories using predefined
tested components. Each unit of code reuse (called a _snippet_) defines the
following:

- _Dockerfile commands_: snippets can provide a blob of text that, after [variable interpolation](#variables),
  is dumped into the generated Dockerfile.
- _Context dependencies_: snippets may expect certain files to exist in the build
  context. They have the option of providing its contents or allow them to be
  fetched from external sources (e.g. database dumps).
- _Documentation_: snippets are encouraged to provide a description containing notes
  to users/maintainers that will be included in the appropriate section in the generated
  Dockerfile.

Each invocation of Dockergen requires a build defintion file (see
[`definition.example.yml`](definition.example.yml)) which provides the following:

- `snippet_sources`: paths to files or directories where referenced snippets are to be found,
- `dockerfile`: a sequence of snippets or literal Dockerfile commands,
- `assets`: fetch rules for context dependencies that snippets declare but do not provide
  contents for (e.g. database dumps, CVS repos)
- `docker_opts`: docker automation configuration: docker run options, built image tag, etc.

The output of Dockergen is a docker build directory containing at the very least a
Dockerfile and a `Makefile`. [This](example) is the generated docker build directory
for [`definition.example.yaml`](definition.example.yml). To reproduce the results:
```bash
git clone http://github.com/amirkdv/dockergen
cd dockergen

bin/dockergen -d definition.example.yml -b apache_app
# [created]      apache_app/Dockerfile
# [created]      apache_app/Makefile
# [created]      apache_app/assets/.gitkeep
# [created]      apache_app/files/supervisor/supervisord.conf
# [created]      apache_app/files/supervisor/apache.conf

make -C apache_app/ build
# docker build logs ...

make -C apache_app/ start
# starts the container in the foreground

# in a separate tab:
curl localhost:8001
# Hello World!
```

Snippets
========

Here is a [possible definition](snippets/apache.yml) for a snippet that installs
Apache and creates a Supervisor program for it (for a more complex snippet see
[`drupal_apache_2.2_site`](snippets/drupal.yml)):
```yaml
- name: apache2
  description: install Apache and configure it under supervisor control
  dockerfile: |
    RUN apt-get install -y apache2
    RUN rm /etc/apache2/sites-enabled/*
    ADD files/supervisor/apache.conf /etc/supervisor/conf.d/apache.conf
    RUN sed -i 's/Listen 80/Listen %%listen_ports%%/' /etc/apache2/ports.conf
  context:
  - filename: files/supervisor/apache.conf
    contents: |
      ; supervisor configuration for Apache
      [program:apache]
      command = /bin/sh -c '. /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND'
```
which can be used like this in the build definition (note `%%listen_ports%%` in
the last line of `dockerfile:`):
```yaml
snippets_sources: ./snippets/apache.yml
dockerfile:
  - # ...
  - snippet: apache2
    vars:
      listen_ports: 8000
  - # ...
```
This will be translated, by Dockergen, to:
* the following lines in the generated Dockerfile:

        # ... [truncated]
        #===============================================================================
        # install Apache and configure it under supervisor control
        #===============================================================================
        RUN apt-get install -y apache2
        RUN rm /etc/apache2/sites-enabled/*
        ADD files/supervisor/apache.conf /etc/supervisor/conf.d/apache.conf
        RUN sed -i 's/Listen 80/Listen 8000/' /etc/apache2/ports.conf
        # ... [truncated]

* the context dependency `files/supervisor/apache2.conf` is created in the build
  context:

        ├── Dockerfile
        └── files
            └── supervisor
                └── apache.conf

Each snippet definition contains:

- `name` (mandatory, used as identifier for the snippet
- `description` (recommended as otherwise the Dockefile entry would have no comments)
- `dockerfile` (optional): A string that is filtered through for variables and
  dumped into the resulting Dockefile.
- `context`: a list of dependencies each containing:
  - `filename` (mandatory): relative path, within the build context, of a
    file that the snippet expects to exist.
  - `contents` (optional): the contents of the given dependency. If not
    provided, the [build definition](#build-definition) must provide a method of
    fetching this file.

Guidelines
----------
For better readability and maintainability, I have found the following
guidelines useful. Dockergen does not enforce any of them but issues a warning
if it catches a violation:

1. To avoid unnecessarily invalidating Docker's cache, Dockergen is smart about
   updating files in the build directory only if they need to change. In the
   same spirit, make sure your snippet `COPY`/`ADD`s its files as late as
   possible.
1. YAML [makes](http://yaml.org/spec/current.html) heavy use of the context that
   each syntactical entity appears in. For example, the second colon in `url:
   http://github.com` is disambiguated from the context. However, to avoid
   complex corner cases quote your strings, via `"` or `'`, or use literal
   blocks, via `|`, instead of relying YAML's disambiguiation magic.
1. Snippets should create their context dependencies under the following
   subdirectories of the build context:
   * `files/` or `scripts/` if the snippet is providing the contents of the
      file,
   * `assets/` if this is an external dependency for which the build definition
      must provide an `asset` with `fetch` rule; e.g. [`mysql_load_dump`](snippets/mysql.yml)
   * `assets/.secret_*` for special external dependencies that are typically
     passwords and the like, e.g. [`set_user_password`](snippets/common.yml).
     However, keep an eye on https://github.com/dotcloud/docker/pull/6697 .
1. Some snippets need to `COPY`/`ADD` helper files to the image. In such cases, as much
   as possible, use a consistent destination, e.g. `/var/build`, for all
   snippets. For example, see [`detect_squid_deb_proxy`](snippets/apt.yml)].
1. Order the terms in a snippet's name in decreasing order of informativeness,
   e.g. `mysql_load_dump` is better than `load_mysql_dump`.
1. If you decide that in a snippet you need to expose the `filename` of a
   context dependency as a variable, e.g. see [`mysql_load_dump`](snippets/mysql.yml),
   use `context_[varname]` to indicate that the path is relative to the build
   context and not a path in the built image.
1. Dockergen does not perform **any** dependency management. If your snippet
   makes an assumption about installed software or existing files (which
   should obviously be minimal), as much as brevity allows, write Dockerfile
   commands that would break `docker build` if the snippet were to be used in a
   situation where your assumptions are false. Specifically:
   * be ware of nesting multiple subshells as they make it harder to catch
     non-zero exit codes.
   * For a chain of actions that require access to a shared constant variables,
     chain the actions in one `RUN`; see, for example, [`drupal_docroot_permissions`](snippets/drupal.yml).
   * For a chain fo actions that require access to shared stateful variables,
     prefer a helper script; see, for example,[`detect_sdp_default_gw'](snippets/apt.yml).
