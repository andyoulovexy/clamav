FROM alpine


RUN apk add --no-cache tini su-exec
RUN set -x \
  && echo "===> Add malice user and malware folder..." \
  && addgroup malice \
  && adduser -S -G malice malice \
  && mkdir /malware \
  && chown -R malice:malice /malware

LABEL maintainer "https://github.com/blacktop"

LABEL malice.plugin.repository = "https://github.com/malice-plugins/clamav.git"
LABEL malice.plugin.category="av"
LABEL malice.plugin.mime="*"
LABEL malice.plugin.docker.engine="*"
COPY clamav-0.105.1.tar.gz /
COPY . /go/src/github.com/malice-plugins/clamav
#RUN echo "export GO111MODULE=on" >> ~/.profile
#RUN echo "export GOPROXY=https://goproxy.cn" >> ~/.profile
#RUN source ~/.profile

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
#RUN apk --update add --no-cache clamav ca-certificates
RUN apk --update add --no-cache -t .build-deps \
  build-base \
  mercurial \
  musl-dev \
  openssl \
  bash \
  wget \
  git \
  gcc \
  go \
  cmake \
  && echo "Building avscan Go binary..." \
  && cd /go/src/github.com/malice-plugins/clamav \
  && export GOPATH=/go \
  && go version \
  && go get \
  && go build -ldflags "-s -w -X main.Version=v$(cat VERSION) -X main.BuildTime=$(date -u +%Y%m%d)" -o /bin/avscan \
  && rm -rf /go /usr/local/go /usr/lib/go /tmp/* \
  && apk del --purge .build-deps
RUN apk add --no-cache \
        bsd-compat-headers \
        bzip2-dev \
        check-dev \
        cmake \
        curl-dev \
        file \
        fts-dev \
        g++ \
        git \
        json-c-dev \
        libmilter-dev \
        libtool \
        libxml2-dev \
        linux-headers \
        make \
        ncurses-dev \
        openssl-dev \
        pcre2-dev \
        py3-pytest \
        zlib-dev \
        rust \
        cargo \
    && \
    cd / &&tar -zvxf clamav-0.105.1.tar.gz &&cd /clamav-0.105.1 && mkdir build &&cd build && \
    cmake .. \
          -DCMAKE_BUILD_TYPE="Release" \
          -DCMAKE_INSTALL_PREFIX="/usr" \
          -DCMAKE_INSTALL_LIBDIR="/usr/lib" \
          -DAPP_CONFIG_DIRECTORY="/etc/clamav" \
          -DDATABASE_DIRECTORY="/var/lib/clamav" \
          -DENABLE_CLAMONACC=OFF \
          -DENABLE_EXAMPLES=OFF \
          -DENABLE_JSON_SHARED=ON \
          -DENABLE_MAN_PAGES=OFF \
          -DENABLE_MILTER=ON \
          -DENABLE_STATIC_LIB=OFF \
    && cmake --build . &&cmake --build . --target install \
&& \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /run/lock/clamd.pid|" \
        -e "s|.*\(LocalSocket\) .*|\1 /run/clamav/clamd.sock|" \
        -e "s|.*\(TCPSocket\) .*|\1 3310|" \
        -e "s|.*\(TCPAddr\) .*|#\1 0.0.0.0|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/clamd.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        "/etc/clamav/clamd.conf.sample" > "/etc/clamav/clamd.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /run/lock/freshclam.pid|" \
        -e "s|.*\(DatabaseOwner\) .*|\1 clamav|" \
        -e "s|^\#\(UpdateLogFile\) .*|\1 /var/log/clamav/freshclam.log|" \
        -e "s|^\#\(NotifyClamd\).*|\1 /etc/clamav/clamd.conf|" \
        -e "s|^\#\(ScriptedUpdates\).*|\1 yes|" \
        "/etc/clamav/freshclam.conf.sample" > "/etc/clamav/freshclam.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /run/lock/clamav-milter.pid|" \
        -e "s|.*\(MilterSocket\) .*|\1 inet:7357|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/milter.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        -e "s|.*\(\ClamdSocket\) .*|\1 unix:/run/clamav/clamd.sock|" \
        "/etc/clamav/clamav-milter.conf.sample" > "/etc/clamav/clamav-milter.conf"
RUN addgroup -S "clamav" && \
    adduser -D -G "clamav" -h "/var/lib/clamav" -s "/bin/false" -S "clamav" && \
    install -d -m 755 -g "clamav" -o "clamav" "/var/log/clamav"
# Update ClamAV Definitions
RUN mkdir -p /opt/malice \
  && chown malice /opt/malice \
  && freshclam

# Add EICAR Test Virus File to malware folder
ADD http://www.eicar.org/download/eicar.com.txt /malware/EICAR

RUN chown malice -R /malware

WORKDIR /malware

ENTRYPOINT ["/bin/avscan"]
CMD ["--help"]
