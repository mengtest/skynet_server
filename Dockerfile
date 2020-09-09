#构建编译环境
FROM alpine:latest as alpine-builder

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories\
    && apk update \
    && apk add --no-cache --virtual .build-deps \
    git \ 
    make \ 
    autoconf \
    g++ \
    readline-dev

#编译
FROM alpine-builder as server-built

COPY ./3rd ./app/3rd
COPY ./src/lualib-src ./app/src/lualib-src
COPY ./src/service-src ./app/src/service-src
COPY ./Makefile ./app/Makefile

RUN cd app \
    && make cleanall && make linux \
    && rm -rf Makefile src/lualib-src src/service-src \
    && cd ./3rd/skynet \
    && rm -rf 3rd Makefile lualib-src platform.mk service-src skynet-src test \
    && apk del .build-deps 
    
#更新lua、配置等文件
FROM alpine:latest as server-sync

COPY . /app
COPY --from=server-built /app /app

RUN cd app \
    && rm -rf tools Makefile src/lualib-src src/service-src \
    && cd ./3rd/skynet \
    && rm -rf 3rd Makefile lualib-src platform.mk service-src skynet-src test

#构建运行环境
FROM alpine:latest as server-run

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories\
    && apk add --no-cache libgcc

#最终镜像
FROM server-run

WORKDIR /app
COPY --from=server-sync /app /app
