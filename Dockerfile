# Offical Docker PHP & Apache image https://hub.docker.com/_/php/
FROM php:7.0-apache

# Install deps
RUN apt-get update && apt-get install -y \
              libcurl4-gnutls-dev \
              libmcrypt-dev \
              libmosquitto-dev \
              git-core \
              cron \
              supervisor \
              redis-tools

# Enable PHP modules
RUN docker-php-ext-install -j$(nproc) mysqli curl json mcrypt gettext
RUN pecl install redis-3.1.6 \
  \ && docker-php-ext-enable redis
RUN pecl install Mosquitto-0.4.0 \
  \ && docker-php-ext-enable mosquitto

RUN a2enmod rewrite

# Add custom PHP config
COPY config/php.ini /usr/local/etc/php/

# NOT USED ANYMORE - GIT CLONE INSTEAD
# Copy in emoncms files, files can be mounted from local FS for dev see docker-compose
# ADD ./emoncms /var/www/html

# Clone in master Emoncms repo & modules - overwritten in development with local FS files
RUN git clone https://github.com/emoncms/emoncms.git /var/www/html
RUN git clone https://github.com/emoncms/dashboard.git /var/www/html/Modules/dashboard
RUN git clone https://github.com/emoncms/graph.git /var/www/html/Modules/graph
RUN git clone https://github.com/emoncms/app /var/www/html/Modules/app
RUN git clone https://github.com/emoncms/sync.git /home/pi/sync

# Setup SYNC Module
RUN chgrp www-data /home/pi
RUN chgrp -R www-data /home/pi/sync
RUN ln -s /var/www/html /var/www/emoncms
RUN ln -s /home/pi/sync/sync-module /var/www/emoncms/Modules/sync
COPY scripts/emoncms-sync.sh /home/pi/sync/emoncms-sync.sh
RUN chmod +x /home/pi/sync/emoncms-sync.sh

# Setup emonpi/service-runner
COPY scripts/service-runner /home/pi/emonpi/service-runner
RUN chmod +x /home/pi/emonpi/service-runner
RUN chgrp -R www-data /home/pi/emonpi
RUN mkdir /home/pi/data
RUN chgrp www-data /home/pi/data
RUN touch /home/pi/data/emoncms-sync.log
RUN chmod 666 /home/pi/data/emoncms-sync.log
 
COPY docker.settings.php /var/www/html/settings.php

# Create folders & set permissions for feed-engine data folders (mounted as docker volumes in docker-compose)
RUN mkdir /var/lib/phpfiwa
RUN mkdir /var/lib/phpfina
RUN mkdir /var/lib/phptimeseries
RUN chown www-data:root /var/lib/phpfiwa
RUN chown www-data:root /var/lib/phpfina
RUN chown www-data:root /var/lib/phptimeseries

# Create Emoncms logfile
RUN touch /var/log/emoncms.log
RUN chmod 666 /var/log/emoncms.log

RUN echo "* * * * * supervisorctl start service-runner" | crontab -
#RUN (crontab -l; echo "* * * * * supervisorctl start secondtask") 2>&1 crontab -

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]

# TODO
# Add Pecl :
# - dio
# - Swiftmailer
