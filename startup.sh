#!/bin/bash
# Debug build/startup
if [ x"$DEBUG" == x"true" ] ; then
	set -e
	set -x
fi

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
	docker.io \
	mysql-client sqlite3 \
	nginx

# Install newer maven
which mvn || {
	MAVEN_BIN="http://ftp.unicamp.br/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
	mkdir -p /opt/maven
	curl $MAVEN_BIN | tar xzf - -C /opt/maven
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvnDebug /usr/local/bin/mvnDebug
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvn /usr/local/bin/mvn
}

# Install IDE
which codebox || {
	npm -g install codebox
	cd /usr/local/lib/node_modules/codebox/node_modules/shux/node_modules/pty.js/lib/pty.js
	make build
	make
}

# Setup the developer account
adduser --gecos "" --disabled-password developer
addgroup developer docker

# Launch IDE on boot
cp codeboxd /etc/init.d/codeboxd
chmod +x /etc/init.d/codeboxd
update-rc.d codeboxd defaults
service codeboxd start

# Expose on port 80
cp codebox.conf /etc/nginx/conf.d/
service nginx reload
