FROM centos:8.3.2011
ENV TZ=UTC-8
ADD ob_build /usr/bin/
ADD python-env-activate.sh /usr/bin/py-env-activate
RUN rm -rf /etc/yum.repos.d/* && curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
RUN yum -y install epel-release && \
    yum -y install libffi-devel bzip2-devel readline readline-devel jq which ncurses-devel bison openssh-clients libaio-0.3.112-1.el8 autoconf automake libtool wget perl-CPAN gettext-devel perl-devel \
    openssl-devel zlib-devel curl-devel expat-devel asciidoc xmlto rpm-build cmake libarchive make gcc gcc-c++ xz-devel \
    python2 python2-pip python2-devel python36 python36-devel python38-devel && yum clean all

# install git
RUN wget http://github.com/git/git/archive/v2.32.0.tar.gz && \
    tar -xvf v2.32.0.tar.gz && \
    rm -f v2.32.0.tar.gz && \
    cd git-* && \
    make configure && \
    ./configure --prefix=/usr && \
    make -j16 && \
    make install

RUN ln -s /usr/bin/python2 /usr/bin/python && ln -s /usr/bin/pip2 /usr/bin/pip && pip install --upgrade pip==19.3.1 && pip install pyinstaller==3.6
# install conda
RUN wget https://github.com/conda-forge/miniforge/releases/download/22.9.0-2/Mambaforge-22.9.0-2-Linux-`uname -m`.sh -P /tmp/
RUN bash /tmp/Mambaforge-22.9.0-2-Linux-`uname -m`.sh  -b -p /opt/conda && rm -rf /tmp/Mambaforge-22.9.0-2-Linux-`uname -m`.sh 
RUN ln -s /opt/conda/bin/conda /usr/bin/conda && conda init && conda create -n py38 python=3.8 && eval "$(conda shell.bash hook)" && conda activate py38 && \
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && pip install wheel && pip install pyinstaller
RUN conda config --set auto_activate_base false
# install nodejs and yarn
RUN curl –sL https://rpm.nodesource.com/setup_16.x | bash -
RUN yum install -y nodejs && yum clean all

RUN npm i yarn tyarn -g