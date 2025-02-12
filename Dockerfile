#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

####################
# Jupyter is the base of the container
####################
FROM jupyter/minimal-notebook:lab-3.3.0

LABEL maintainer="Developer Team <engineering@databloom.ai>"

USER root
ENV DEBIAN_FRONTEND noninteractive
####################
# Install Java
####################
ARG JAVA_VERSION=11

RUN apt-get update \
 && apt-get install -y curl \
                       software-properties-common \
                       gnupg \
                       libzip5 \
                       libsnappy1v5  \
                       libssl-dev

# Install Zulu OpenJdk 11 (LTS)
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9 \
 && curl https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-2_all.deb --output zulu-repo_1.0.0-2_all.deb \
 && apt-get install ./zulu-repo_1.0.0-2_all.deb \
 && apt-get update \
 && apt-get install -y zulu${JAVA_VERSION}-jdk \
 && rm -f zulu-repo_1.0.0-2_all.deb

ENV JAVA_HOME /usr/lib/jvm/zulu${JAVA_VERSION}

# Unpack and install the kernel
RUN curl -L https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip > ijava-kernel.zip
RUN unzip ijava-kernel.zip -d ijava-kernel \
 && cd ijava-kernel \
 && python3 install.py --sys-prefix

#TODO: add scala kernel

# Cleanup
RUN rm ijava-kernel.zip

####################
# Install Hadoop
####################

ENV HADOOP_VERSION  2.7.7
ENV HADOOP_HOME     /usr/local/hadoop
ENV HADOOP_OPTS     -Djava.library.path=/usr/local/hadoop/lib/native
ENV PATH            $PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

RUN curl http://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz --output hadoop-${HADOOP_VERSION}.tar.gz \
 && tar -zxf hadoop-${HADOOP_VERSION}.tar.gz \
 && rm hadoop-${HADOOP_VERSION}.tar.gz \
 && mv hadoop-${HADOOP_VERSION} ${HADOOP_HOME} \
 && mkdir -p /usr/local/hadoop/logs

# Overwrite default HADOOP configuration files with our config files
COPY hadoop/conf $HADOOP_HOME/etc/hadoop/

# Formatting HDFS
RUN mkdir -p /data/dfs/data /data/dfs/name /data/dfs/namesecondary
VOLUME /data/dfs

#TODO: start hadoop at the moment of start the container
####################
# PORTS
####################
#
# http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.3.0/bk_HDP_Reference_Guide/content/reference_chap2.html
# http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/cdh_ig_ports_cdh5.html
# http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/core-default.xml
# http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml

# HDFS: NameNode (NN):
#   9000  = fs.defaultFS			(IPC / File system metadata operations)
#   8022  = dfs.namenode.servicerpc-address	(optional port used by HDFS daemons to avoid sharing RPC port)
#   50070 = dfs.namenode.http-address	(HTTP  / NN Web UI)
#   50470 = dfs.namenode.https-address	(HTTPS / Secure UI)
# HDFS: DataNode (DN):
#   50010 = dfs.datanode.address		(Data transfer)
#   50020 = dfs.datanode.ipc.address	(IPC / metadata operations)
#   50075 = dfs.datanode.http.address	(HTTP  / DN Web UI)
#   50475 = dfs.datanode.https.address	(HTTPS / Secure UI)
# HDFS: Secondary NameNode (SNN)
#   50090 = dfs.secondary.http.address	(HTTP / Checkpoint for NameNode metadata)
EXPOSE 9000 50070 50010 50020 50075 50090

####################
# Install Maven
####################
ARG MAVEN_VERSION=3.6.3
ENV MAVEN_HOME    /usr/local/maven
ENV PATH          $PATH:$MAVEN_HOME/bin

RUN curl https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip --output apache-maven-${MAVEN_VERSION}-bin.zip \
 && unzip apache-maven-${MAVEN_VERSION}-bin.zip \
 && mv apache-maven-3.6.3 ${MAVEN_HOME} \
 && rm -r apache-maven-${MAVEN_VERSION}-bin.zip

####################
# Install Spark
####################

# SPARK
ENV SPARK_VERSION 3.1.2
ENV SPARK_HOME    /usr/local/spark
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH          $PATH:${SPARK_HOME}/bin

RUN curl https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop2.7.tgz --output spark-${SPARK_VERSION}-bin-hadoop2.7.tgz  \
 && tar -zxf spark-${SPARK_VERSION}-bin-hadoop2.7.tgz \
 && rm spark-${SPARK_VERSION}-bin-hadoop2.7.tgz \
 && mv spark-${SPARK_VERSION}-bin-hadoop2.7 ${SPARK_HOME}

#TODO: start spark at the moment of start the container

####################
# Example add
####################

COPY example ${HOME}/

RUN rm -rf ijava-kernel work


####################
# Install Scala Kernel for jupyter
####################

RUN curl -Lo /usr/local/bin/coursier https://github.com/coursier/coursier/releases/download/v2.0.0-RC3-2/coursier && \
    chmod +x /usr/local/bin/coursier

# Set user back to priviledged user.
USER ${NB_USER}

COPY bin/install-kernels.sh .
RUN ./install-kernels.sh && \
    rm install-kernels.sh