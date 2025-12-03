FROM alpine:3.19
RUN apk add --no-cache mysql-client socat
COPY watchdog.sh /watchdog.sh
RUN chmod +x /watchdog.sh
ENTRYPOINT ["/watchdog.sh"]
