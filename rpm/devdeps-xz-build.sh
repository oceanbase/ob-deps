CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-xz"}
VERSION=${3:-"5.2.2"}
RELEASE=${4:-"4"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/xz-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://nchc.dl.sourceforge.net/project/lzmautils/xz-5.2.2.tar.gz -O $ROOT_DIR/xz-$VERSION.tar.gz --no-check-certificate
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE