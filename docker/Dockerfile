FROM openjdk:17-jdk-slim

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