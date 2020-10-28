#构建编译环境
FROM alpine:latest as alpine-builder

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories\
    && apk update \
    && apk add --no-cache --virtual .build-deps \
    git \ 
    make \ 
    autoconf \
    g++ \
    readline-dev \
    tzdata

ENV TZ Asia/Shanghai

#编译
FROM alpine-builder as server-built

COPY ./.git ./app/.git
COPY ./3rd ./app/3rd
COPY ./src ./app/src
COPY ./Makefile ./app/Makefile

RUN cd app \
    && git submodule update --init \
    && make cleanall && make linux \
    && rm -rf Makefile src ./3rd/lua-cjson .git \
    && cd ./3rd/skynet \
    && rm -rf 3rd examples lualib-src service-src skynet-src test Makefile platform.mk skynet .git \
    && apk del .build-deps 
    
#构建运行环境
FROM alpine:latest as server-run

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories\
    && apk add --no-cache \
    libgcc \
    tzdata 

ENV TZ Asia/Shanghai

#最终镜像
FROM server-run

COPY --from=server-built /app /app
