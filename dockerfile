CMD ["bash"]
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends ca-certificates netbase tzdata ; rm -rf /var/lib/apt/lists/*
ENV GPG_KEY=E3FF2839C048B25C084DEBE9B26995E310250568
ENV PYTHON_VERSION=3.9.2
RUN set -ex  \
        && savedAptMark="$(apt-mark showmanual)"  \
        && apt-get update  \
        && apt-get install -y --no-install-recommends dpkg-dev gcc libbluetooth-dev libbz2-dev libc6-dev libexpat1-dev libffi-dev libgdbm-dev liblzma-dev libncursesw5-dev libreadline-dev libsqlite3-dev libssl-dev make tk-dev uuid-dev wget xz-utils zlib1g-dev $(command -v gpg > /dev/null || echo 'gnupg dirmngr')  \
        && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"  \
        && wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"  \
        && export GNUPGHOME="$(mktemp -d)"  \
        && gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"  \
        && gpg --batch --verify python.tar.xz.asc python.tar.xz  \
        && { command -v gpgconf > /dev/null  \
        && gpgconf --kill all || :; }  \
        && rm -rf "$GNUPGHOME" python.tar.xz.asc  \
        && mkdir -p /usr/src/python  \
        && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz  \
        && rm python.tar.xz  \
        && cd /usr/src/python  \
        && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"  \
        && ./configure --build="$gnuArch" --enable-loadable-sqlite-extensions --enable-optimizations --enable-option-checking=fatal --enable-shared --with-system-expat --with-system-ffi --without-ensurepip  \
        && make -j "$(nproc)" LDFLAGS="-Wl,--strip-all"  \
        && make install  \
        && rm -rf /usr/src/python  \
        && find /usr/local -depth \( \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \) -exec rm -rf '{}' +  \
        && ldconfig  \
        && apt-mark auto '.*' > /dev/null  \
        && apt-mark manual $savedAptMark  \
        && find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' | awk '/=>/ { print $(NF-1) }' | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -r apt-mark manual  \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false  \
        && rm -rf /var/lib/apt/lists/*  \
        && python3 --version
RUN cd /usr/local/bin  \
        && ln -s idle3 idle  \
        && ln -s pydoc3 pydoc  \
        && ln -s python3 python  \
        && ln -s python3-config python-config
ENV PYTHON_PIP_VERSION=21.0.1
ENV PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/b60e2320d9e8d02348525bd74e871e466afdf77c/get-pip.py
ENV PYTHON_GET_PIP_SHA256=c3b81e5d06371e135fb3156dc7d8fd6270735088428c4a9a5ec1f342e2024565
RUN set -ex; savedAptMark="$(apt-mark showmanual)"; apt-get update; apt-get install -y --no-install-recommends wget; wget -O get-pip.py "$PYTHON_GET_PIP_URL"; echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; apt-mark auto '.*' > /dev/null; [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; rm -rf /var/lib/apt/lists/*; python get-pip.py --disable-pip-version-check --no-cache-dir "pip==$PYTHON_PIP_VERSION" ; pip --version; find /usr/local -depth \( \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \) -exec rm -rf '{}' +; rm -f get-pip.py
CMD ["python3"]
ARG GIT_REPO=https://github.com/Siriussee/autoremove-torrents.git
ARG BRANCH=master
WORKDIR /app
RUN |2 GIT_REPO=https://github.com/Siriussee/autoremove-torrents.git BRANCH=master RUN apt-get update  \
        && apt-get install git gcc cron -y -q  \
        && git clone $GIT_REPO  \
        && cd autoremove-torrents  \
        && git checkout $BRANCH  \
        && python3 setup.py install  \
        && apt-get purge gcc git -y  \
        && apt-get clean # buildkit
ADD cron.sh /usr/bin/cron.sh # buildkit
        usr/
        usr/bin/
        usr/bin/cron.sh

RUN |2 GIT_REPO=https://github.com/Siriussee/autoremove-torrents.git BRANCH=master RUN chmod +x /usr/bin/cron.sh # buildkit
RUN |2 GIT_REPO=https://github.com/Siriussee/autoremove-torrents.git BRANCH=master RUN touch /var/log/autoremove-torrents.log # buildkit
COPY config.example.yml config.yml # buildkit
        app/
        app/config.yml

ENV OPTS=-c /app/config.yml
ENV CRON=*/5 * * * *
ENTRYPOINT ["/bin/sh" "/usr/bin/cron.sh"]
