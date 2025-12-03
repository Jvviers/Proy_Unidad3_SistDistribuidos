FROM alpine:3.19
RUN apk add --no-cache postgresql-client socat
COPY watchdog.sh /watchdog.sh
RUN chmod +x /watchdog.sh
ENTRYPOINT ["/watchdog.sh"]
