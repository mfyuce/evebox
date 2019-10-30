FROM ubuntu:16.04

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install apt-utils
RUN apt-get autoremove
RUN apt-get install -y python
RUN apt-get -y install software-properties-common
RUN add-apt-repository ppa:longsleep/golang-backports
RUN apt-get -y update
RUN apt-get -y install \
    make \
	git \
	gcc \
	g++ \
	zip \
	sudo \
	rpm \
	gcc-mingw-w64 \
	clang \
	patch \
	golang-go \
	gcc-aarch64-linux-gnu \
	gcc-arm-linux-gnueabi \
	ruby-full \
	curl

RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

RUN apt-get install -y nodejs

# Install fpm.
RUN gem install --bindir=/usr/local/bin fpm

RUN groupadd --gid 5000 builder
RUN groupadd wheel
RUN useradd --uid 5000 --gid 5000 --password "" --groups wheel builder
RUN echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

COPY docker-entrypoint.sh /
RUN ["chmod", "+x", "/docker-entrypoint.sh"]
ENTRYPOINT ["/docker-entrypoint.sh"]
