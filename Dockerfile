# START STAGE 1
FROM openjdk:8-jdk-slim as builder

USER root

ENV ANT_VERSION 1.10.13
ENV ANT_HOME /etc/ant-${ANT_VERSION}

WORKDIR /tmp

RUN apt-get update && apt-get install -y \
    git \
    curl \
    nodejs \ 
    npm

RUN curl -L -o apache-ant-${ANT_VERSION}-bin.tar.gz https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mkdir ant-${ANT_VERSION} \
    && tar -zxvf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
    && rm apache-ant-${ANT_VERSION}-bin.tar.gz \
    && rm -rf ant-${ANT_VERSION} \
    && rm -rf ${ANT_HOME}/manual \
    && unset ANT_VERSION

ENV PATH ${PATH}:${ANT_HOME}/bin

FROM builder as tei

ARG TEMPLATING_VERSION=1.1.0
ARG PUBLISHER_LIB_VERSION=4.0.0
ARG ROUTER_VERSION=1.8.1

ARG ADMIN_PASS=dm18IWqn0OQBfSh5KubR
## stgm-data at gitlab.existsolutions.com/stgm/stgm-data.git
ARG ACCESS_TOKEN_NAME1=stgm-data
ARG ACCESS_TOKEN_VALUE1=glpat-4XXzd7AZan7zGWMaVUXw

## stgm at gitlab.existsolutions.com/stgm/stgm.git
ARG ACCESS_TOKEN_NAME2=stgm
ARG ACCESS_TOKEN_VALUE2=glpat-zc9eFJzwjGeFA8hdUNrg


# add key
###RUN  mkdir -p ~/.ssh && ssh-keyscan -t rsa gitlab.existsolutions.com >> ~/.ssh/known_hosts
RUN  git clone --depth 1 -b main https://${ACCESS_TOKEN_NAME1}:${ACCESS_TOKEN_VALUE1}@gitlab.existsolutions.com/missiven/stgm-data.git \ 
    && cd stgm-data \
    && ant


RUN  git clone --depth 1 -b main https://${ACCESS_TOKEN_NAME2}:${ACCESS_TOKEN_VALUE2}@gitlab.existsolutions.com/missiven/stgm.git \
    && cd stgm \
    && ant

RUN curl -L -o /tmp/roaster-${ROUTER_VERSION}.xar http://exist-db.org/exist/apps/public-repo/public/roaster-${ROUTER_VERSION}.xar
RUN curl -L -o /tmp/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar
RUN curl -L -o /tmp/templating-${TEMPLATING_VERSION}.xar http://exist-db.org/exist/apps/public-repo/public/templating-${TEMPLATING_VERSION}.xar

FROM duncdrum/existdb:6.2.0-debug-j8

COPY --from=tei /tmp/stgm-data/build/*.xar /exist/autodeploy/
COPY --from=tei /tmp/stgm/build/*.xar /exist/autodeploy/
COPY --from=tei /tmp/*.xar /exist/autodeploy/

WORKDIR /exist

ARG HTTP_PORT=8080
ARG HTTPS_PORT=8443

ARG CONTEXT_PATH=auto
ARG PROXY_CACHING=false

ENV JAVA_TOOL_OPTIONS \
  -Dfile.encoding=UTF8 \
  -Dsun.jnu.encoding=UTF-8 \
  -Djava.awt.headless=true \
  -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
  -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
  -Dlog4j.configurationFile=/exist/etc/log4j2.xml \
  -Dexist.home=/exist \
  -Dexist.configurationFile=/exist/etc/conf.xml \
  -Djetty.home=/exist \
  -Dexist.jetty.config=/exist/etc/jetty/standard.enabled-jetty-configs \  
  -Dteipublisher.context-path=${CONTEXT_PATH} \
  -Dteipublisher.proxy-caching=${PROXY_CACHING} \
  -XX:+UseG1GC \
  -XX:+UseStringDeduplication \
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
  -XX:+ExitOnOutOfMemoryError

# pre-populate the database by launching it once and change default pw

RUN [ "java", "org.exist.start.Main", "client", "--no-gui",  "-l", "-u", "admin", "-P", "" ]


EXPOSE ${HTTP_PORT} ${HTTPS_PORT}
