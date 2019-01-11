FROM ubuntu:18.04
MAINTAINER Samuel Fernando Mesa Giraldo <samuelmesa@gmail.com>

ENV VERSION 2019-01-09
ENV TERM xterm
ENV LANG C
ENV PG_VERSION 10
ENV PATH /usr/lib/postgresql/$PG_VERSION/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DB hsrs_micka6

RUN apt-get -y update \
    && apt-get -y upgrade

RUN buildDeps='cmake gnupg software-properties-common g++ make build-essential git' \
    && set -x \
    && apt-get install -y -y $buildDeps --no-install-recommends \
    && apt-get clean

####### Add repository and install PHP5.6 ###############

RUN add-apt-repository -y ppa:ondrej/php \
    && apt -y update

RUN set -x \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx postgresql postgis postgresql-10-postgis-2.4 postgresql-10-postgis-scripts \
    php5.6-fpm php5.6-xsl php5.6-pgsql php5.6-curl \
    zip unzip php5.6-zip curl

####### Download and install PHP COMPOSER ###############

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    # Make sure we're installing what we think we're installing!
    && php5.6 -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php5.6 /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
    && rm -f /tmp/composer-setup.*

####### Download MICKA and install packages ###############

RUN cd /var/www/html/ \
    && git clone https://github.com/hsrs-cz/Micka.git \
    && cd Micka/php \
    && php5.6 /usr/local/bin/composer install \
    && chmod -Rfv a+rwx  log/ temp/

####### install GOSU for manage users ###############

ENV GOSU_VERSION 1.7
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get purge -y ca-certificates wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

####### Clean APT Packages ################################

RUN gosu nobody true \
    && apt-get purge -y --auto-remove cmake gnupg \
    software-properties-common g++ make build-essential git \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/    

####### SQL and scripts ###############

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

RUN mkdir /docker-entrypoint-initdb.d  && cd /docker-entrypoint-initdb.d \
    && cp /var/www/html/Micka/php/install/1_create_database.sql . \
    && cp /var/www/html/Micka/php/install/2_create_table.sql  . \
    && cp /var/www/html/Micka/php/install/3_insert_data_basic.sql  . \
    && cp /var/www/html/Micka/php/install/4_insert_standard_schema.sql  . \
    && cp /var/www/html/Micka/php/install/5_insert_profiles.sql  . \
    && cp /var/www/html/Micka/php/install/6_00_label_esp.sql  . \
    && cp /var/www/html/Micka/php/install/6_00_label_eng.sql .

COPY confs/default /etc/nginx/sites-available/
COPY confs/config.local.neon /var/www/html/Micka/php/app/config/
COPY docker-entrypoint.sh /usr/local/bin/

RUN ln -s /usr/local/bin/docker-entrypoint.sh /

####### VOLUMES and PORTS ###############

VOLUME /var/lib/postgresql/data

EXPOSE 5432
EXPOSE 80

ENTRYPOINT ["sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres"]    
