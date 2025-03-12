ARG BASE_IMAGE="openjdk:21-jdk-slim"
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG CREATED=""
ARG SOURCE=""
ARG VERSION=""

LABEL org.opencontainers.image.authors="Eclipse Foundation"
LABEL org.opencontainers.image.created="${CREATED}"
LABEL org.opencontainers.image.source="${SOURCE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.base.name="${BASE_IMAGE}"

### user name recognition at runtime w/ an arbitrary uid - for OpenShift deployments
COPY uid_entrypoint /usr/local/bin/uid_entrypoint
RUN chmod u+x /usr/local/bin/uid_entrypoint && \
    chgrp 0 /usr/local/bin/uid_entrypoint && \
    chmod g=u /usr/local/bin/uid_entrypoint /etc/passwd
ENTRYPOINT [ "uid_entrypoint", "/infocenter/startDockerInfoCenter.sh" ]

RUN mkdir -p /infocenter/workspace
WORKDIR /infocenter
COPY tmp/* /infocenter/

RUN chgrp -R 0 /infocenter && \
    chmod -R g=u /infocenter && \
    chmod +x /infocenter/startDockerInfoCenter.sh

USER 10001

EXPOSE 8086