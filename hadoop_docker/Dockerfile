FROM ubuntu:20.04

ADD ./etc/hadoop-3.2.2.tar.gz /usr/local/
RUN mv /usr/local/hadoop-3.2.2 /usr/local/hadoop

RUN apt-get update && apt-get install -y openssh-server sudo openjdk-11-jdk
RUN apt-get install -y net-tools vim
ENV HADOOP_HOME /usr/local/hadoop
ENV JAVA_HOME /usr/lib/jvm/java-1.11.0-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#permitrootlogin.*/PermitRootLogin yes/ig' /etc/ssh/sshd_config
RUN echo "\nHost 192.168.0.*\n"\
         "  StrictHostKeyChecking no\n"\
         "  UserKnownHostsFile=/dev/null"\
         >> /etc/ssh/ssh_config

ADD ./init.sh /
RUN chmod +x /init.sh
ADD ./ssh/ /root/.ssh/
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

ADD ./conf/core-site.xml /usr/local/hadoop/etc/hadoop/
ADD ./conf/hdfs-site.xml /usr/local/hadoop/etc/hadoop/
RUN  echo "\nexport HDFS_NAMENODE_USER=\"root\"\n"\
          "export HDFS_DATANODE_USER=\"root\"\n"\
          "export HDFS_SECONDARYNAMENODE_USER=\"root\"\n"\
          "export YARN_RESOURCEMANAGER_USER=\"root\"\n"\
          "export YARN_NODEMANAGER_USER=\"root\"\n"\
          "export JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64/\n"\
          >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh

ADD ./conf/mapred-site.xml /usr/local/hadoop/etc/hadoop/
ADD ./conf/yarn-site.xml /usr/local/hadoop/etc/hadoop/
RUN  echo "\n192.168.0.2    hadoop01\n"\
          "192.168.0.3  hadoop02\n"\
          >> /etc/hosts
RUN echo "hadoop01\n"\
         "hadoop02\n"\
         > /usr/local/hadoop/etc/hadoop/workers
RUN hdfs namenode -format -y
ENTRYPOINT ["/init.sh"]
