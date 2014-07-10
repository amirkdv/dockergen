FROM ubuntu:12.04

#===============================================================================
# Configure apt and install basic utilities used by other provisioning commands
#===============================================================================
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update

#===============================================================================
# install supervisor with minimal configuration
#===============================================================================
RUN apt-get install -y python-setuptools && easy_install supervisor
RUN mkdir -p /etc/supervisor/conf.d
ADD files/supervisor/supervisord.conf /etc/supervisord.conf

#===============================================================================
# install Apache and configure it under supervisor control
#===============================================================================
RUN apt-get install -y apache2
RUN rm /etc/apache2/sites-enabled/*
ADD files/supervisor/apache.conf /etc/supervisor/conf.d/apache.conf
RUN sed -i 's/Listen 80/Listen 80/' /etc/apache2/ports.conf

#===============================================================================
# install vhost file for Apache 2.2. and populate docrooot
#===============================================================================
RUN a2enmod rewrite
ADD files/apache_vhost /etc/apache2/sites-available/hello
ADD assets/site /var/www/example
RUN a2ensite hello

CMD ["supervisord", "-c", "/etc/supervisord.conf", "-n"]
