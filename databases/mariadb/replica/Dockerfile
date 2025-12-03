FROM mariadb:10.5
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=inventorydb
ENV MYSQL_USER=inventory
ENV MYSQL_PASSWORD=inventory123

COPY my.cnf /etc/mysql/conf.d/my.cnf
COPY setup-replica.sh /setup-replica.sh
RUN chmod +x /setup-replica.sh

ENTRYPOINT ["/setup-replica.sh"]
