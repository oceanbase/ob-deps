CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-apr"}
VERSION=${3:-"1.7.5"}
RELEASE=${4:-"3"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apr-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://dlcdn.apache.org//apr/apr-$VERSION.tar.gz -O $ROOT_DIR/apr-$VERSION.tar.gz --no-check-certificate
    wget https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz -O $ROOT_DIR/apr-util-1.6.3.tar.gz
fi

export CFLAGS="-fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC -pie -fstack-protector-strong"

ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=$(uname -p)

if [[ "${ID}" == "alinux" && "$arch" == "aarch64" ]]; then
    export CFLAGS="$CFLAGS -mno-outline-atomics"
    export CXXFLAGS="$CXXFLAGS -mno-outline-atomics"
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE