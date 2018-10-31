FROM ubuntu:latest

ENV SUMO_VERSION 1_0_1
ENV XERCES_VERSION 3.2.2
ENV PROJ_VERSION 5.2.0
ENV SUMO_HOME /opt/sumo

# from https://github.com/docker-library/python/blob/7a794688c7246e7eff898f5288716a3e7dc08484/3.7/alpine3.8/Dockerfile
ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.7.1
ENV DEBIAN_FRONTEND noninteractive
#ENV LD_RUN_PATH /usr/local/lib
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

COPY "$GPG_KEY".gpg /root/

RUN apt-get update -qq \
	&& apt-get install -yy \
		build-essential \
		libbz2-dev \
		libc6-dev \
		libffi-dev \
		libgdbm-dev \
		libncurses5-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		openssl \
		python-dev \
		python-pip \
		python-setuptools \
		python-smbus \
		tk-dev \
		zlib1g-dev \
		gnupg \
		wget \
		autoconf \
		libproj-dev \
		proj-bin \
		proj-data \
		libtool \
		libgdal-dev \
		libxerces-c-dev \
		libfox-1.6-0 \
		libfox-1.6-dev \
		locales \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8 \
	&& wget -t 3 -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -t 3 -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --import /root/"$GPG_KEY".gpg \
	&& rm /root/"$GPG_KEY".gpg \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		#--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--with-ensurepip=install \
		--with-hash-algorithm=siphash24 \
	&& make -j "$(nproc)" \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
		EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
	&& make install \
	&& rm -rf /usr/src/python \
	&& python3 --version \
# make some useful symlinks that are expected to exist
	&& cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config \
# Download and extract SUMO source code
	&& wget -t 3 https://github.com/eclipse/sumo/archive/v$SUMO_VERSION.tar.gz -O /tmp/$SUMO_VERSION.tar.gz \
	&& mkdir -p $SUMO_HOME \
	&& tar xzf /tmp/$SUMO_VERSION.tar.gz -C /opt/sumo --strip 1 \
	&& rm /tmp/$SUMO_VERSION.tar.gz

# Configure and build from source.
# Ensure the installation works. If this call fails, the whole build will fail.
WORKDIR $SUMO_HOME
RUN make -f Makefile.cvs \
	&& ./configure \
	&& make -j$(nproc) \
	&& make install clean \
	&& sumo

# Add volume to allow for host data to be used
RUN mkdir ~/data
VOLUME ~/data

# Expose a port so that SUMO can be started with --remote-port 1234 to be controlled from outside Docker
EXPOSE 1234

ENTRYPOINT ["sumo"]
CMD ["--help"]
