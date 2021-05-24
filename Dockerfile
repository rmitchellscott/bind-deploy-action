FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openssh-client \
    git \
    rsync

COPY . .

RUN chmod +x ./docker-entrypoint.sh
ADD rsyncignore /etc/
ENTRYPOINT ["./docker-entrypoint.sh"]