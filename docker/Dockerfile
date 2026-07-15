FROM apache/hadoop:3.3.6

USER root

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

RUN yum install -y python3 bind-utils net-tools && yum clean all && rm -rf /var/cache/yum

ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN mkdir -p /data/hdfs/namenode /data/hdfs/datanode /data/yarn/local /data/yarn/logs && chown -R hadoop:hadoop /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9870 9000 9864 8088 8042

ENTRYPOINT ["/entrypoint.sh"]
