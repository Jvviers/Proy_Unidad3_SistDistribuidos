FROM mysql:8

RUN microdnf update -y && microdnf install -y socat && microdnf clean all

COPY watchdog.sh /watchdog.sh
RUN chmod +x /watchdog.sh

ENTRYPOINT ["/watchdog.sh"]
