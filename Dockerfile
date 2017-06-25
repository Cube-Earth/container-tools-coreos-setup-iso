FROM alpine:latest

RUN apk add --update wget ca-certificates gnupg bash sudo xorriso syslinux squashfs-tools abuild gcc alpine-sdk jq
RUN addgroup sudo && \
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	adduser -D -g '' -G abuild -s /sbin/nologin build && \
	adduser build sudo && \
	sudo -u build abuild-keygen -ian && \
	abuild-keygen -ian && \
	mkdir -p /var/cache/distfiles && \
	chgrp abuild /var/cache/distfiles && \
	chmod g+w /var/cache/distfiles && \
	curl -Ls `curl -s https://api.github.com/repos/Cube-Earth/tools-coreos-ct/releases/latest | jq -r '.assets[].browser_download_url'` | gunzip -c - > /usr/bin/ct && \
	chmod +x /usr/bin/ct
	
USER build

COPY files/ /tmp/

RUN sudo chown -R build /tmp && \
	find /tmp -name .DS_Store -delete
	
WORKDIR /tmp

VOLUME /iso

ENTRYPOINT [ "./create.sh" ]
