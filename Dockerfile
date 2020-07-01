FROM debian:buster-slim AS mc
RUN apt-get update && \
  apt-get install -y --no-install-recommends wget ca-certificates
RUN wget https://dl.min.io/client/mc/release/linux-amd64/mc && \
  chmod +x mc

FROM alpine AS clone
WORKDIR /clone
RUN apk add git
RUN git clone https://github.com/cisco/libsrtp -b v2.3.0 --depth=1 && \
	git clone https://gitlab.freedesktop.org/libnice/libnice -b 0.1.17 --depth=1 && \
	git clone https://github.com/meetecho/janus-gateway -b v0.10.2 --depth=1

FROM debian:buster-slim AS build
RUN apt-get -y update && \
	apt-get install -y --no-install-recommends \
		libmicrohttpd-dev \
		libjansson-dev \
		libssl-dev \
		libglib2.0-dev \
		libogg-dev \
		libcurl4-openssl-dev \
		libconfig-dev \
		libusrsctp-dev \
		libwebsockets-dev \
		libnanomsg-dev \
		librabbitmq-dev \
		pkg-config \
		gengetopt \
		libtool \
		automake \
		build-essential \
		git \
		gtk-doc-tools \
		ca-certificates \
		libavutil-dev libavcodec-dev libavformat-dev && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY --from=clone /clone .

RUN cd libsrtp && \
	./configure --prefix=/usr --enable-openssl && \
	make shared_library && \
	make install

RUN cd libnice && \
	./autogen.sh && \
	./configure --prefix=/usr && \
	make && \
	make install

RUN cd janus-gateway && \
	./autogen.sh && \
	./configure --prefix=/usr/local --enable-post-processing && \
	make && \
	make install && \
	make configs

FROM debian:buster-slim

ARG BUILD_DATE="undefined"
ARG GIT_BRANCH="undefined"
ARG GIT_COMMIT="undefined"
ARG VERSION="undefined"

LABEL build_date=${BUILD_DATE}
LABEL git_branch=${GIT_BRANCH}
LABEL git_commit=${GIT_COMMIT}
LABEL version=${VERSION}

COPY --from=build /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so.1
RUN ln -s /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so

COPY --from=build /usr/lib/libnice.la /usr/lib/libnice.la
COPY --from=build /usr/lib/libnice.so.10.10.0 /usr/lib/libnice.so.10.10.0
RUN ln -s /usr/lib/libnice.so.10.10.0 /usr/lib/libnice.so.10
RUN ln -s /usr/lib/libnice.so.10.10.0 /usr/lib/libnice.so

COPY --from=build /usr/local/bin/janus /usr/local/bin/janus
COPY --from=build /usr/local/bin/janus-cfgconv /usr/local/bin/janus-cfgconv
COPY --from=build /usr/local/bin/janus-pp-rec /usr/local/bin/janus-pp-rec
COPY --from=build /usr/local/etc/janus /usr/local/etc/janus
COPY --from=build /usr/local/lib/janus /usr/local/lib/janus
COPY --from=build /usr/local/share/janus /usr/local/share/janus

COPY --from=mc mc /usr/local/bin/mc
RUN mc config host rm s3

RUN apt-get -y update && \
	apt-get install -y --no-install-recommends \
		libmicrohttpd12 \
		libjansson4 \
		libssl1.1 \
		libglib2.0-0 \
		libogg0 \
		libcurl4 \
		libconfig9 \
		libusrsctp1 \
		libwebsockets8 \
		libnanomsg5 \
		librabbitmq4 \
		libavutil56 libavcodec58 libavformat58 \
		ca-certificates \
		inotify-tools task-spooler ffmpeg jq && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENV BUILD_DATE=${BUILD_DATE}
ENV GIT_BRANCH=${GIT_BRANCH}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV VERSION=${VERSION}

EXPOSE 10000-10200/udp
EXPOSE 8088
EXPOSE 8089
EXPOSE 8889
EXPOSE 8000
EXPOSE 7088
EXPOSE 7089

WORKDIR /
VOLUME [ "/data" ]
COPY docker-entrypoint.sh post-process.sh ./
ENTRYPOINT janus --daemon --log-file=/log.txt && ./docker-entrypoint.sh
