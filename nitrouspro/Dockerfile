# Custom Docker build to setup my Nitrous PRO
# workspace with my own custom tools
FROM quay.io/nitrous/gcloud:latest
MAINTAINER Ronoaldo JLP <ronoaldo@gmail.com>

# Install some extra programs for cross project development
RUN apt-get install -qq --yes --no-install-recommends \
	exuberant-ctags ant \
	ruby ruby-dev ruby-compass \
	python-dev python3-dev \
	build-essential devscripts \
	golang golang-go.tools && \
	apt-get clean
RUN curl -sL https://deb.nodesource.com/setup_0.12 |\
	bash - && sudo apt-get install -y nodejs
RUN npm -g install grunt-cli less gulp-cli bower cordova ionic
RUN mkdir -p /opt/maven/ && \
	curl http://ftp.unicamp.br/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz |\
	tar xzf - -C /opt/maven && \
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvnDebug /usr/local/bin/mvnDebug && \
	ln -s /opt/maven/apache-maven-3.3.3/bin/mvn /usr/local/bin/mvn

# Setup some extra goodies on user home
USER nitrous
ENV GOPATH /home/nitrous/code/go
RUN hg clone https://bitbucket.org/ronoaldo/tools /home/nitrous/tools
RUN rm -rvf /home/nitrous/.vim
RUN git clone https://github.com/gmarik/Vundle ~/.vim/bundle/Vundle.vim
RUN echo 'source ~/tools/etc/vimrc' > /home/nitrous/.vimrc &&\
	/home/nitrous/tools/bin/vim-update-bundles &&\
	vim +GoInstallBinaries +qall
RUN cd ~ && wget https://storage.googleapis.com/appengine-sdks/featured/go_appengine_sdk_linux_amd64-1.9.24.zip &&\
	unzip go_appengine_sdk_linux_amd64-1.9.24.zip && rm go_appengine_sdk_linux_amd64-1.9.24.zip
RUN echo 'export PATH=$PATH:$HOME/bin:$HOME/code/go/bin:$HOME/go_appengine' >> ~/.zshrc

USER root