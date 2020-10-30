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

RUN git clone https://github.com/dingdalong/skynet_test.git /app\
    && cd app && git submodule update --init && make linux \
    && rm -rf Makefile src .git ./3rd \
    && apk del .build-deps 

#构建运行环境
FROM alpine:latest as server-run

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories\
    && apk add --no-cache \
    libgcc \
    tzdata \
    busybox-extras

ENV TZ Asia/Shanghai

#最终镜像
FROM server-run

COPY --from=server-built /app /app
