# vim:set ft=dockerfile:
FROM debian:stretch-slim

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
        && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Env section
ENV GOSU_VERSION 1.11
ENV LANG en_US.utf8

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# grab gosu for easy step-down from root
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates wget gnupg dirmngr lsb-release \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc"

ENV PG_REPO_KEY GPG-KEY-POSTGRESPRO
ENV GPG_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN export GNUPGHOME="$(mktemp -d)" \
	&& mkdir ~/.gnupg && echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf \
	&& (gpg --no-tty --keyserver ipv4.pool.sks-keyservers.net --recv-keys $GPG_KEY \
		|| gpg --no-tty --keyserver pgp.mit.edu --recv-keys $GPG_KEY \
		|| gpg --no-tty --keyserver keyserver.pgp.com --recv-keys $GPG_KEY) \
	&& gpg --no-tty --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& wget --quiet -O - http://repo.postgrespro.ru/keys/$PG_REPO_KEY | apt-key add - \
	&& rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget gnupg dirmngr

RUN mkdir /docker-entrypoint-init.d

# Version env
ENV PG_MAJOR 10
ENV PG_MINOR 9.1
ENV PG_RELEASE $PG_MAJOR.$PG_MINOR
ENV PG_VERSION $PG_RELEASE-1.stretch.pro

# Install pgpro
RUN echo "deb http://repo.postgrespro.ru/pgpro-archive/pgpro-$PG_RELEASE/debian $(lsb_release -cs) main" > /etc/apt/sources.list.d/postgrespro.list \
	&& apt-get update \
	&& apt-get install -y postgrespro-std-$PG_MAJOR-client \
	&& rm -rf /var/lib/apt/lists/*

ENV PATH /opt/pgpro/std-$PG_MAJOR/bin:$PATH

RUN mkdir -p /home/postgres \
	&& chown postgres: /home/postgres

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
