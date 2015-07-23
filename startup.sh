#!/bin/bash

# Copyright 2015 Ronoaldo JLP
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script can be used as a startup script to launch and setup
# a development box with Codebox IDE (https://github.com/CodeboxIDE/codebox)

# Debug during VM preparation
if [ x"$DEBUG" == x"true" ] ; then
	set -e
	set -x
fi

# Quiet installation for debian packages
export DEBIAN_FRONTEND=noninteractive

# Update package lists and upgrade installed programs
apt-get -qq update && apt-get -qq upgrade --yes

# Install/upgrade packages in the VM
apt-get install -qq --yes \
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
# Post-install setup
update-command-not-found


# Helper function to fetch instance custom metadata
# Usage:
#   metadata key default-value
metadata() {
  _url="http://metadata.google.internal/computeMetadata/v1/instance/$1"
	# Return the value found, or the default value if the metadata value does not exists
	if curl --fail -s ${_url} -H 'Metadata-Flavor: Google' > /dev/null ; then
		curl --fail -s ${_url} -H 'Metadata-Flavor: Google'
	else
		echo -n "$2"
	fi
}

# Detect password from metadata server, if available
export PASSWORD="$(dd if=/dev/urandom bs=12 count=1 status=none | base64)"
export PASSWORD="$(metadata 'attributes/codebox-password' "$PASSWORD")"
# Default port to launch the IDE
export PORT="$(metadata 'attributes/codebox-port' '2000')"

# Setup data disk as home partition
DATA_DISK=$(metadata 'attributes/codebox-datadisk' '')
case $DATA_DISK in
	"")
		echo "No data disk specified. Skipping ..."
	;;
	*)
		echo "Mounting $DATA_DISK as /home/ ..."
		DISK_DEVICE="/dev/disk/by-id/google-$DATA_DISK"
		MOUNT_POINT="/home/"
		if [ -e $DISK_DEVICE ] ; then
			/usr/share/google/safe_format_and_mount -m "mkfs.ext4 -F" $DISK_DEVICE $MOUNT_POINT
		else
			echo "The specified disk name is not attached to the instance!"
		fi
	;;
esac

# TODO(ronoaldo): use Debian repository maven.
# Maven 3.1+ made significant changes
# and it is not included as part of the current Debian stable release, however
# there are packages on Sid and Testing that will potentially get into
# the backports release soon.
if [ ! -f /usr/local/bin/mvn ] ; then
	MAVEN_BIN="http://ftp.unicamp.br/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
	mkdir -p /opt/maven
	curl -s $MAVEN_BIN | tar xzf - -C /opt/maven
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvnDebug /usr/local/bin/mvnDebug
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvn /usr/local/bin/mvn
fi

# Setup the developer account
if ! getent passwd developer ; then
	adduser --gecos "Developer,,," --disabled-password developer
	addgroup developer docker
fi

# Make shure all files are owned by the developer account under /home
chown -R developer:developer /home/developer

# Install Codebox IDE from NPM and configure as a service
# TODO(ronoaldo): use a packaged version of codebox
if [ ! -f /usr/local/bin/codebox ] ; then
	export HOME=/home/developer
	cd $HOME
	npm -g install codebox
	# TODO(ronoaldo): fix on the source tree/vendored dependency
	# See: http://stackoverflow.com/questions/23570023/issues-in-finding-node-package-when-running-codebox
	cd /usr/local/lib/node_modules/codebox/node_modules/shux/node_modules/pty.js
	make clean
	make
fi

# Setup daemon script
cat > /etc/init.d/codeboxd <<EOF
#!/bin/sh

### BEGIN INIT INFO
# Provides:          codeboxd
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start development box environment
# Description:       This file should be used to construct scripts to be
#                    placed in /etc/init.d.  This example start a
#                    single forking daemon capable of writing a pid
#                    file.  To get other behavoirs, implemend
#                    do_start(), do_stop() or other functions to
#                    override the defaults in /lib/init/init-d-script.
# Author: Ronoaldo JLP <ronoaldo@gmail.com>
### END INIT INFO

DESC="Codebox Development Environment"
DAEMON=/usr/local/bin/codebox

do_start() {
	# Start as a daemon for the developer user
	start-stop-daemon --start --chuid developer --chdir /home/developer --background --verbose \
		-x \$DAEMON -- run . --port ${PORT} --users 'developer:${PASSWORD}' --hostname localhost
}

do_stop() {
	# We should have only one running anyway
	killall -9 node
}

case \$1 in
	start)   do_start ;;
	stop)    do_stop ;;
	restart) do_stop ;  do_start ;;
esac
EOF
chmod +x /etc/init.d/codeboxd
update-rc.d codeboxd defaults

# Expose on port 80 using Nginx reverse proxy
cat > /etc/nginx/conf.d/codebox.conf <<EOF
map \$http_upgrade \$connection_upgrade {
	default upgrade;
	'' close;
}

upstream websocket {
	server localhost:${PORT};
}

server {
	listen 80;
	location / {
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://localhost:${PORT};
	}

	location /socket.io {
		proxy_pass http://websocket;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;
	}
}
EOF
rm -vf /etc/nginx/sites-enabled/default # Disable default site

# Restart the services after a sucessfull boot
service codeboxd restart
service nginx restart

# Show user instructions on serial console
cat <<EOF
******************************************************

Your cloud IDE is ready!

Codebox was installed and launched on port $PORT,
and proxied on port 80 using Nginx.

You can login with:

* Username: developer
* Password: $PASSWORD
* URL: http://$(metadata 'network-interfaces/0/access-configs/0/external-ip')/

Happy hacking!

******************************************************
EOF
