`dockergen` simplifies code re-use in performing common tasks in Docker
container provisioning. Each action is defined as a snippet, for example (see
`snippets/apache.yml`):
```yml
- name: apache
  description: install Apache and configure it under supervisor control
  steps:
  - run: apt-get install -y apache2
  - run: rm /etc/apache2/sites-enabled/*
  - add:
      destination: etc/supervisor/conf.d/apache.conf
      filename: supervisor/apache.conf
      contents: |
        ; supervisor configuration for Apache
        [program:apache]
        command = /bin/sh -c '. /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND'
```
which will result in the following snippet in the resulting `Dockerfile`:
```
#===============================================================================
# install Apache and configure it under supervisor control
#===============================================================================
RUN apt-get install -y apache2
RUN rm /etc/apache2/sites-enabled/*
ADD files/supervisor/apache.conf etc/supervisor/conf.d/apache.conf
```
and the file `supervisor/apache.conf` being created in the docker build directory:
```
; supervisor configuration for Apache
[program:apache]
command = /bin/sh -c '. /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND'
```

## Example usage
The example defintion file installs and configures Apache unser Supervisor and
creates a `Hello World` Apache site served on port 8001 of the docker host.
* Create docker build directory from a definition file:

        bin/dockergen -d definition.example.yml -o apache_app
        # updated file build/Dockerfile
        # updated file build/Makefile
This will create the direcory `apache_app` with the following contents:

        |-- Dockerfile
        |-- files
        |   |-- apache
        |   |   |-- rpaf.conf
        |   |   `-- vhost
        |   `-- supervisor
        |       |-- apache.conf
        |       `-- supervisord.conf
        `-- Makefile
* Build the docker image using the prepopulated `make` targets:

        cd apache_app
        make build
        # mkdir -p assets/site && echo 'Hello World' > assets/site/index.html
        # docker build --tag apache_app .
        # ... [docker build logs]
        # Successfully built 00208c6413c5

* Start the docker container:

        make start
        # docker run --detach --name apache_app --publish 8001:80 apache_app
        # d20dcb5f3780fc5638e8dcc8b27a3dbcfb6772e20790cc2e962c7648092933ed

        curl localhost:8001
        # Hello World
