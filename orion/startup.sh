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
# a development box with Orion (https://orion.eclipse.org/)

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
	tmux vim nano emacs exuberant-ctags command-not-found bash-completion \
	subversion mercurial git \
	build-essential devscripts \
	curl wget \
	npm npm2deb nodejs nodejs-legacy \
	openjdk-7-jdk openjdk-8-jdk ant \
	python-dev python3-dev \
	ruby ruby-dev ruby-compass \
	golang-go golang-go.tools \
	docker.io \
	mysql-client sqlite3 \
	nginx

# Install some basic tools
npm -g install grunt-cli gulp-cli bower less

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
export PASSWORD="$(metadata 'attributes/orion-password' "$PASSWORD")"
# Default port to launch the IDE
export PORT="$(metadata 'attributes/orion-port' '2000')"

# Setup data disk as home partition
DATA_DISK=$(metadata 'attributes/orion-datadisk' '')
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
	echo "Installing maven ..."
	MAVEN_BIN="http://ftp.unicamp.br/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz"
	mkdir -p /opt/maven
	curl -s $MAVEN_BIN | tar xzf - -C /opt/maven
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvnDebug /usr/local/bin/mvnDebug
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvn /usr/local/bin/mvn
fi

# Setup Orion
if [ ! -d /opt/orion ] ; then
	echo "Installing orion ..."
	ORION_BIN="http://download.eclipse.org/orion/drops/R-10.0-201510301610/eclipse-orion-10.0-linux.gtk.x86_64.zip"
	ORION_TMP=$(mktemp)
	mkdir -p /opt/orion
	curl -s "$ORION_BIN" > $ORION_TMP
	unzip -q -n $ORION_TMP -d /opt/orion/
	cat > /opt/orion/eclipse/orion.ini <<EOF
-startup
plugins/org.eclipse.equinox.launcher_1.3.0.v20140415-2008.jar
--launcher.library
plugins/org.eclipse.equinox.launcher.gtk.linux.x86_64_1.1.200.v20140603-1326
-consoleLog
-console
-data
/home/developer/orion
-nosplash
-vmargs
-Dorg.eclipse.equinox.http.jetty.http.port=$PORT
-Dorg.eclipse.equinox.http.jetty.autostart=false
-Dhelp.lucene.tokenizer=standard
-Xms40m
-Xmx384m
EOF
	cat > /opt/orion/eclipse/orion.conf <<EOF
orion.file.allowedPaths=/home/developer
orion.auth.admin.default.password=$PASSWORD \
EOF
	ln -s /opt/orion/eclipse/orion /usr/local/bin/orion
fi

# Setup the developer account
if ! getent passwd developer ; then
	adduser --gecos "Developer,,," --disabled-password developer
	addgroup developer docker
fi

# Make shure all files are owned by the developer account under /home
chown -R developer:developer /home/developer

# Setup daemon script
cat > /etc/init.d/oriond <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          oriond
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

DESC="Development Environment"
DAEMON=/usr/local/bin/orion

do_start() {
	# Start as a daemon for the developer user
	start-stop-daemon --start --chuid developer --chdir /home/developer --background --verbose -x \$DAEMON
}

do_stop() {
	# We should have only one running anyway
	ps fax | awk '/orion/ {print $1}' | xargs kill -9
}

case \$1 in
	start)   do_start ;;
	stop)    do_stop ;;
	restart) do_stop ;  do_start ;;
esac
EOF
chmod +x /etc/init.d/oriond
update-rc.d oriond defaults


# Expose on port 80 using Nginx reverse proxy
cat > /etc/nginx/conf.d/orion.conf <<EOF
map \$http_upgrade \$connection_upgrade {
	default upgrade;
	'' close;
}

upstream websocket {
	server 127.0.0.1:${PORT};
}

server {
	listen 80;

	location / {
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

		set \$proxyport ${PORT};
		if (\$host ~* ([2-9][0-9][0-9][0-9])\..*) {
			set \$proxyport \$1;
		}

		proxy_pass http://127.0.0.1:\$proxyport;
	}

	location /shell/tty {
		proxy_pass http://websocket;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;
	}
}
EOF
rm -vf /etc/nginx/sites-enabled/default # Disable default site

# Restart the services after a sucessfull boot
service nginx restart

# Show user instructions on serial console
cat <<EOF
******************************************************

Your cloud IDE is ready!

Orion was installed and launched on port $PORT,
and proxied on port 80 using Nginx.

You can login with:

* Username: admin
* Password: $PASSWORD
* URL: http://$(metadata 'network-interfaces/0/access-configs/0/external-ip')/

Happy hacking!

******************************************************
EOF
