ARG VERSION
FROM docker.io/weaveworks/scope:${VERSION}
RUN addgroup -g 7007 -S weave && \
    adduser -u 7007 -D -h /home/weave -S weave -G weave
RUN mkdir /var/run/weave && chown -R weave:weave /var/run/weave
RUN chown -R weave:weave /etc/service
USER weave
