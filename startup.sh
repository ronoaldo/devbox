#!/bin/bash
set -e

# Quiet setup
export DEBIAN_FRONTEND=noninteractive

# Update/Upgrade
apt-get update && apt-get upgrade --yes

# Install dependencies
apt-get install --yes \
	tmux vim emacs exuberant-ctags command-not-found \
	subversion mercurial git \
	build-essential devscripts \
	curl wget \
	npm npm2deb nodejs nodejs-legacy \
	openjdk-7-jdk openjdk-8-jdk ant \
	python-dev python3-dev \
	golang golang-go.tools \
	ruby ruby-dev \
	mysql-client sqlite3

# Install newer maven
MAVEN_BIN="http://ftp.unicamp.br/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
mkdir -p /opt/maven
curl $MAVEN_BIN | tar xzf - -C /opt/maven
echo 'PATH=$PATH:/opt/maven/apache-maven-3.3.3/bin' >> /etc/profile

# Install IDE and User
npm -g install codebox
adduser --gecos "" --disabled-password developer

# Launch IDE on boot
cp codeboxd /etc/init.d/codeboxd
chmod +x /etc/init.d/codeboxd
update-rc.d codeboxd defaults
service codeboxd start
