FROM git.joinsharkey.org/sharkey/sharkey:latest

COPY patches /patches

RUN apk add patch && \
    patch -p0 < /patches/fake-deepl-server.patch && \
    patch -p0 < /patches/zond.patch