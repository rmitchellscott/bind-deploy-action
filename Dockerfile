FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    openssh-client \
    git \
    rsync

ADD rsyncignore /etc/

WORKDIR /zones