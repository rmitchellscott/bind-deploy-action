FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    openssh-client \
    git \
    rsync

COPY ./docker-entrypoint.sh zones/

RUN chmod +x zones/docker-entrypoint.sh
ADD rsyncignore /etc/

WORKDIR /zones
ENTRYPOINT ["./docker-entrypoint.sh"]