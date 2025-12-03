FROM mysql:8

ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=reportsdb
ENV MYSQL_USER=reports
ENV MYSQL_PASSWORD=reports123

COPY my.cnf /etc/mysql/conf.d/my.cnf
COPY init-replica.sh /docker-entrypoint-initdb.d/10-init-replica.sh
