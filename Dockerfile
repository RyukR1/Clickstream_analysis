# Base Image: A pre-configured Hadoop/Hive/Pig ecosystem
ARG BASE_IMAGE=silicoflare/hadoop:amd
FROM ${BASE_IMAGE}

# Set the working directory inside the container
WORKDIR /clickstream

# Copy custom configurations pointing to the multi-node architecture
COPY hadoop_config/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml
COPY hadoop_config/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml
COPY hadoop_config/yarn-site.xml /usr/local/hadoop/etc/hadoop/yarn-site.xml

# Copy all the project directories and files into the image
COPY . /clickstream/

# Make sure all bash scripts are executable
RUN chmod +x /clickstream/*.sh

# Start command keeps the container alive in the background
CMD ["sleep", "infinity"]
