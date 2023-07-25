FROM centos:7.9.2009
ENV TZ=UTC-8
ADD ob_build /usr/bin/
ADD python-env-activate.sh /usr/bin/py-env-activate
RUN yum install -y wget && wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo && \
    yum -y install libffi-devel bzip2-devel readline readline-devel jq which bison ncurses-devel libaio-0.3.109-13.el7 autoconf automake libtool perl-CPAN gettext-devel perl-devel openssl-devel zlib-devel curl-devel python-devel xz-devel \
    expat-devel asciidoc xmlto rpm-build cmake make gcc gcc-c++ python-pip python36 python3-devel && yum clean all
# install git
RUN wget http://github.com/git/git/archive/v2.32.0.tar.gz && \
    tar -xvf v2.32.0.tar.gz && \
    rm -f v2.32.0.tar.gz && \
    cd git-* && \
    make configure && \
    ./configure --prefix=/usr && \
    make -j16 && \
    make install
RUN pip install --upgrade pip==19.3.1 && pip install pyinstaller==3.6
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