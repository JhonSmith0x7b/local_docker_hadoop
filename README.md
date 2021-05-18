# 本地docker化hadoop分布式集群搭建

> 本文旨在docker环境搭建一个分布式hadoop分布式集群, 可以用于学习或者调研.

## 如何使用?

根目录 `docker-compose up`
`docker exec -it hadoop_hadoop01_1 bash`
`start-dfs.sh`
`start-yarn.sh`


## 1. 镜像列表

* [ubuntu:20.04](https://hub.docker.com/_/ubuntu)

## 2. 资源列表

* [hadoop 3.2.2](https://hadoop.apache.org/releases.html)

## 3. 配置ssh

ssh配置主要分为两个部分, 第一个是sshd的服务安装, 第二个是集群见免密登陆.

### 3.1 sshd服务安装以及启动

`Dockerfile`
---
```
apt-get update && apt-get install -y openssh-server
RUN sed -i 's/#permitrootlogin.*/PermitRootLogin yes/ig' /etc/ssh/sshd_config
RUN echo 'root:root' | chpasswd
ENTRYPOINT service ssh restart && tail -f /dev/null
```

这里的sshd服务安装, 直接通过内置的apt就可以安装. 但是有一点需要注意, 就是**启动ssh必须要在entrypoint中去做**, 之前有试过run跟cmd都无法启动

### 3.2 ssh免密登陆

免密其实很简单, 但由于我们是本地docker化, 生成公钥私钥可以在生成镜像前就做完, 而且多个机器可以共用一套密钥, 减少我们的配置成本.

密钥生成
```
ssh-keygen -t rsa
```
一路回车, 会有两个文件, `id_rsa`, `id_rsa.pub`

`Dockerfile`
---

```
RUN echo "\nHost 192.168.0.*\n"\
         "  StrictHostKeyChecking no\n"\
         "  UserKnownHostsFile=/dev/null"\
         >> /etc/ssh/ssh_config
ADD ./ssh/ /root/.ssh/
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
```

上面生成的两个文件, 通过add, 直接加到镜像中的`.ssh`路径下. 并且把公钥cat到免密配置中.
上面的echo是为了跳过ssh连接时候的确认环节. 

## 4. 基础环境配置

### 4.1 JAVA

java最重要的就是`JAVA_HOME`, 安装可以通过apt安装openjdk.

`Dockerfile`
---
```
RUN apt-get install -y openjdk-11-jdk
ENV JAVA_HOME  /usr/lib/jvm/java-1.11.0-openjdk-amd64/
```

### 4.2 固定IP

由于配置集群的ip需要是固定的, 所以需要额外配置一下. 我的方式是通过`docker-compose`的设置, 给他们固定的子网IP

`docker-compose.yml`
---
```
version: "3.7"
services:
    hadoop01:
        build: ./hadoop_docker/
        privileged: true
        expose:
            - "22"
        ports:
            - "9870:9870"
            - "8088:8088"
        networks:
            test_sub:
                ipv4_address: 192.168.0.2
    hadoop02:
        build: ./hadoop_docker/
        privileged: true
        expose:
            - "22"
        networks:
            test_sub:
                ipv4_address: 192.168.0.3

networks:
    test_sub:
        ipam:
            config:
                - subnet: 192.168.0.0/28
```

这里首先声明了一个子网`test_sub`, 然后上面再设置ipv4的固定地址, 很好理解.

## 5. hadoop集群配置

我配置的是两个节点, 两个节点都是工作节点, 也是数据节点, 其中`hadoop01`为master节点, 负担`namenode`, `resourceManager`等服务.

### 5.1 环境设置

`Dockerfile`
---
```
ADD ./etc/hadoop-3.2.2.tar.gz /usr/local/
RUN mv /usr/local/hadoop-3.2.2 /usr/local/hadoop
ENV HADOOP_HOME /usr/local/hadoop
RUN  echo "\n192.168.0.2    hadoop01\n"\
          "192.168.0.3  hadoop02\n"\
          >> /etc/hosts
```

### 5.2 hdfs相关配置

`Dockerfile`
---
```
RUN  echo "\nexport HDFS_NAMENODE_USER=\"root\"\n"\
          "export HDFS_DATANODE_USER=\"root\"\n"\
          "export HDFS_SECONDARYNAMENODE_USER=\"root\"\n"\
          "export YARN_RESOURCEMANAGER_USER=\"root\"\n"\
          "export YARN_NODEMANAGER_USER=\"root\"\n"\
          "export JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64/\n"\
          >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh
ADD ./conf/core-site.xml /usr/local/hadoop/etc/hadoop/
ADD ./conf/hdfs-site.xml /usr/local/hadoop/etc/hadoop/
``

`./conf/core-site.xml`
---
```
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://hadoop01:9000</value>
    </property>
</configuration
```

`.conf/hdfs-site.xml`
---
```
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>


<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
```

### 5.3 yarn设置

`Dockerfile`
---
```
ADD ./conf/mapred-site.xml /usr/local/hadoop/etc/hadoop/
ADD ./conf/yarn-site.xml /usr/local/hadoop/etc/hadoop/
```

`./conf/mapred-site.xml`
---
```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
```

`./conf/yarn-site.xml`
---
```
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>hadoop01</value>
    </property>
</configuration>
```

