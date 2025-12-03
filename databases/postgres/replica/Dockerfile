FROM postgres:15
ENV POSTGRES_DB=ordersdb
ENV POSTGRES_USER=orders
ENV POSTGRES_PASSWORD=orders123

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
