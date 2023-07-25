CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-apr"}
VERSION=${3:-"1.6.5"}
RELEASE=${4:-"3"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apr-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://dlcdn.apache.org//apr/apr-1.6.5.tar.gz -O $ROOT_DIR/apr-$VERSION.tar.gz --no-check-certificate
    wget https://archive.apache.org/dist/apr/apr-util-1.6.1.tar.gz -O $ROOT_DIR/apr-util-1.6.1.tar.gz
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE