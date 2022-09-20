FROM node:10-alpine

LABEL Author="Pranav-SA"

RUN npm install -g selenium-side-runner

ADD docker-entrypoint.sh /opt/bin/docker-entrypoint.sh
RUN chmod +x /opt/bin/docker-entrypoint.sh

RUN mkdir /sides

WORKDIR /root

VOLUME [ "/sides" ]

CMD "/opt/bin/docker-entrypoint.sh"
