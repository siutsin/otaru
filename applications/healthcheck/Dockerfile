FROM alpine:latest
RUN apk add --no-cache curl bash
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh
CMD ["/healthcheck.sh"]
