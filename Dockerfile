FROM ubuntu:latest

COPY . .
COPY rsyncignore /etc/
RUN chmod +x /docker-entrypoint.sh

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openssh-client \
    git \
    rsync

ENTRYPOINT ["/docker-entrypoint.sh"]