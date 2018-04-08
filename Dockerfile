FROM resin/rpi-raspbian:stretch
MAINTAINER Johannes Alt <altjohannes510@gmail.com>

RUN apt-get update && \
	apt-get install -y \
	apache2 \
	apache2-bin \
	libapache2-mod-php \
	php-curl \
	php-ldap \
	php-mysql \
	php-mcrypt \
	php-gd \
	php-xml \
	php-mbstring \
	php-zip \
	php-bcmath \
	patch \
	curl \
	vim \
	git \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /var/www/html
RUN rm index.html && \
	git init && \
	git remote add origin https://github.com/snipe/snipe-it.git && \
	git fetch origin && \
	git checkout -b master origin/master

RUN phpenmod mcrypt
RUN phpenmod gd
RUN phpenmod bcmath

RUN sed -i 's/variables_order = .*/variables_order = "EGPCS"/' /etc/php/7.0/apache2/php.ini
RUN sed -i 's/variables_order = .*/variables_order = "EGPCS"/' /etc/php/7.0/cli/php.ini

RUN useradd -m --uid 1000 --gid 50 docker

RUN echo export APACHE_RUN_USER=docker >> /etc/apache2/envvars
RUN echo export APACHE_RUN_GROUP=staff >> /etc/apache2/envvars

RUN cp /var/www/html/docker/000-default.conf /etc/apache2/sites-enabled/000-default.conf

#SSL
RUN mkdir -p /var/lib/snipeit/ssl
RUN cp /var/www/html/docker/001-default-ssl.conf /etc/apache2/sites-enabled/001-default-ssl.conf

RUN a2enmod ssl
#RUN a2ensite 001-default-ssl.conf

RUN a2enmod rewrite

############ INITIAL APPLICATION SETUP #####################

WORKDIR /var/www/html

#Append to bootstrap file (less brittle than 'patch')
# RUN sed -i 's/return $app;/$env="production";\nreturn $app;/' bootstrap/start.php

#all configuration files
# COPY docker/*.php /var/www/html/app/config/production/
RUN cp /var/www/html/docker/docker.env /var/www/html/.env
RUN chown -R docker /var/www/html

RUN \
	rm -r "/var/www/html/storage/private_uploads" && ln -fs "/var/lib/snipeit/data/private_uploads" "/var/www/html/storage/private_uploads" \
      && rm -rf "/var/www/html/public/uploads" && ln -fs "/var/lib/snipeit/data/uploads" "/var/www/html/public/uploads" \
      && rm -r "/var/www/html/storage/app/backups" && ln -fs "/var/lib/snipeit/dumps" "/var/www/html/storage/app/backups"

############## DEPENDENCIES via COMPOSER ###################

#global install of composer
RUN cd /tmp;curl -sS https://getcomposer.org/installer | php;mv /tmp/composer.phar /usr/local/bin/composer

# Get dependencies
USER docker
RUN cd /var/www/html;composer install && rm -rf /home/docker/.composer/cache
USER root

############### APPLICATION INSTALL/INIT #################

#RUN php artisan app:install
# too interactive! Try something else

#COPY docker/app_install.exp /tmp/app_install.exp
#RUN chmod +x /tmp/app_install.exp
#RUN /tmp/app_install.exp

############### DATA VOLUME #################

VOLUME ["/var/lib/snipeit"]

EXPOSE 80
EXPOSE 443

# By default start up apache in the foreground, override with /bin/bash for interative.
CMD /usr/sbin/apache2ctl -D FOREGROUND
