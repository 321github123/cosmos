ARG OPENC3_DEPENDENCY_REGISTRY=docker.io

FROM ${OPENC3_DEPENDENCY_REGISTRY}/redis:7.2

COPY cacert.pem /devel/cacert.pem
ENV SSL_CERT_FILE=/devel/cacert.pem
ENV CURL_CA_BUNDLE=/devel/cacert.pem
ENV REQUESTS_CA_BUNDLE=/devel/cacert.pem
ENV NODE_EXTRA_CA_CERTS=/devel/cacert.pem

RUN mkdir /config
COPY redis.conf /config/.
COPY redis_ephemeral.conf /config/.
COPY users.acl /config/.

EXPOSE 3680

RUN apt update \
  && apt upgrade -y

CMD [ "redis-server", "/config/redis.conf" ]
