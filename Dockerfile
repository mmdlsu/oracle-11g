FROM centos:7
MAINTAINER jaspeen

ENV ORACLE_SID=orcl \
    ORACLE_PWD=oracle \
    ORACLE_CHARACTERSET=AL32UTF8 \
    PASSWORD_NO_EXPIRE=true \
    LOGIN_ATTEMPTS_UNLIMITED=true

COPY assets/colorecho \
     assets/limits.conf \
     assets/profile \
     assets/setup.sh \
     assets/sysctl.conf \
     /assets/

RUN chmod -R 755 /assets
RUN /assets/setup.sh

COPY assets /assets
RUN chmod -R 755 /assets

COPY install /install

EXPOSE 1521
EXPOSE 8080

CMD ["/assets/entrypoint.sh"]
