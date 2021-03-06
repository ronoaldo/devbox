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

# Quiet installation for debian packages
export DEBIAN_FRONTEND=noninteractive

# Setup testing, with negative pinning
if [ ! -f /etc/apt/sources.list.d/testing.list ] ; then
	echo "Installing base software ... "
	echo     'deb http://httpredir.debian.org/debian testing main' >> /etc/apt/sources.list.d/testing.list
	echo -e 'Package: *\nPin: release a=testing\nPin-Priority: -1' >> /etc/apt/preferences.d/testing

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
		docker.io \
		mysql-client sqlite3 \
		nginx
	
	# Cherry pick some packages from testing
	apt-get install -ttesting -qq --yes \
		golang-go golang-golang-x-tools maven
	
	# Install some basic tools
	npm -g install grunt-cli gulp-cli bower less
	
	# Post-install setup
	update-command-not-found
fi

# Detect password from metadata server, if available
export USER="$(metadata 'attributes/orion-unixuser' 'developer')"
export PASSWORD="$(dd if=/dev/urandom bs=12 count=1 status=none | base64)"
export PASSWORD="$(metadata 'attributes/orion-password' "$PASSWORD")"
export PORT="$(metadata 'attributes/orion-port' '2000')"
export GOTTY_PORT=2022

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

# Install Orion
if [ ! -d /opt/orion ] ; then
	echo "Installing orion ..."
	ORION_BIN="http://download.eclipse.org/orion/drops/R-10.0-201510301610/eclipse-orion-10.0-linux.gtk.x86_64.zip"
	ORION_TMP=$(mktemp)
	mkdir -p /opt/orion
	curl -s "$ORION_BIN" > $ORION_TMP
	unzip -q -n $ORION_TMP -d /opt/orion/
	ln -s /opt/orion/eclipse/orion /usr/local/bin/orion
fi

# Setup default Orion configuration
cat > /opt/orion/eclipse/orion.ini <<EOF
-startup
plugins/org.eclipse.equinox.launcher_1.3.0.v20140415-2008.jar
--launcher.library
plugins/org.eclipse.equinox.launcher.gtk.linux.x86_64_1.1.200.v20140603-1326
-consoleLog
-console
-data
/home/$USER/orion
-nosplash
-vmargs
-Dorg.eclipse.equinox.http.jetty.http.port=$PORT
-Dorg.eclipse.equinox.http.jetty.autostart=false
-Dhelp.lucene.tokenizer=standard
-Xms40m
-Xmx384m
EOF

cat > /opt/orion/eclipse/orion.conf <<EOF
orion.file.allowedPaths=/home/$USER
orion.auth.admin.default.password=$PASSWORD
orion.auth.user.creation=admin
EOF

# Setup the developer unix account
if ! getent passwd $USER ; then
	adduser --gecos "$USER,,," --disabled-password $USER
	addgroup $USER docker
fi

# Make shure all files are owned by the $USER account under /home
chown -R $USER:$USER /home/$USER

# Setup daemon script
cat > /etc/init.d/oriond <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:	  oriond
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start development box environment
# Description:       Startup script to execute the development environment as $USER
# Author: Ronoaldo JLP <ronoaldo@gmail.com>
### END INIT INFO

DESC="Development Environment"
DAEMON=/usr/local/bin/orion

do_start() {
	# Start as a daemon for the $USER user
	start-stop-daemon --start --chuid $USER --chdir /opt/orion/eclipse/ --background --verbose -x \$DAEMON
}

do_stop() {
	# We should have only one running anyway
	ps fax | awk '/orion/ {print \$1}' | xargs kill -9
}

case \$1 in
	start)   do_start ;;
	stop)    do_stop ;;
	restart) do_stop ;  do_start ;;
esac
EOF

chmod +x /etc/init.d/oriond
update-rc.d oriond defaults

# Setup remote TTY with random URL endpoint
if [ ! -f /usr/local/bin/gotty ] ; then 
	export GOPATH=$(mktemp -d)
	go get -d github.com/yudai/gotty
	go build -o /usr/local/bin/gotty github.com/yudai/gotty
fi

cat > /etc/gotty.conf <<EOF
address = "0.0.0.0"
port = "$GOTTY_PORT"
permit_write = true
enable_basic_auth = true
credential = "$USER:$PASSWORD"
title_format = "Shell ({{.Hostname}})"
preferences {
	desktop_notification_bell = true
	environment = {
		"TERM" = "xterm-256color"
	}
	font_size = 14
	background_color = "rgb(16, 16, 16)"
}
EOF

cat > /etc/init.d/gottyd <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:	  gottyd
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start remote websocket shell
# Description:       Startup script to execute websocket tty as $USER
# Author: Ronoaldo JLP <ronoaldo@gmail.com>
### END INIT INFO

DESC="Websocket shell"
DAEMON=/usr/local/bin/gotty

do_start() {
	# Start as a daemon for the $USER user
	start-stop-daemon --start --chuid $USER --chdir /home/$USER --background --verbose -x \$DAEMON -- \
		--config /etc/gotty.conf /bin/bash -l
}

do_stop() {
	# We should have only one running anyway
	ps fax | awk '/bin\\/gotty/ {print \$1}' | xargs kill -9
}

case \$1 in
	start)   do_start ;;
	stop)    do_stop ;;
	restart) do_stop ;  do_start ;;
esac
EOF

chmod +x /etc/init.d/gottyd
update-rc.d gottyd defaults

# Expose on port 80 using Nginx reverse proxy
cat > /etc/nginx/conf.d/orion.conf <<EOF
map \$http_upgrade \$connection_upgrade {
	default upgrade;
	'' close;
}

upstream gotty {
	server 127.0.0.1:$GOTTY_PORT;
}

server {
	listen 80;

	location / {
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

		set \$proxyport $PORT;
		if (\$host ~* ([2-9][0-9][0-9][0-9])\..*) {
			set \$proxyport \$1;
		}

		proxy_pass http://127.0.0.1:\$proxyport;
	}

	location /shell/gotty/ {
		proxy_pass http://gotty/;
		proxy_http_version 1.1;
		proxy_read_timeout 3600;
		proxy_buffer_size 512;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;
		proxy_set_header Origin "";
	}
}
EOF
rm -vf /etc/nginx/sites-enabled/default # Disable default site

# Restart the services after a sucessfull boot
for s in oriond gottyd nginx ; do 
	service $s restart
done

# Show user instructions on serial console
cat <<EOF
******************************************************

Your cloud IDE is ready!

Orion was installed and launched on port $PORT,
and proxied on port 80 using Nginx.
GoTTY was installed and launched on port $GOTTY_PORT,
also proxied on port 80 using Nginx.

You can login with:

* Username: admin
* Password: $PASSWORD
* IDE: http://$(metadata 'network-interfaces/0/access-configs/0/external-ip')/
* TTY: http://$(metadata 'network-interfaces/0/access-configs/0/external-ip')/tty/gotty/

Happy hacking!

******************************************************
EOF
