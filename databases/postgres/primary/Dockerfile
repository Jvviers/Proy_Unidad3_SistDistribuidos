FROM postgres:15

ENV POSTGRES_DB=ordersdb
ENV POSTGRES_USER=orders
ENV POSTGRES_PASSWORD=orders123

COPY postgresql.config /etc/postgresql/postgresql.conf
COPY pg_hba.conf /pg_hba.conf
COPY init-hba.sh /docker-entrypoint-initdb.d/00-init-hba.sh
COPY init.sql /docker-entrypoint-initdb.d/init.sql
RUN chmod +x /docker-entrypoint-initdb.d/00-init-hba.sh
