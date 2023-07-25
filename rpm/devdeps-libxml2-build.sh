CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-libxml2"}
VERSION=${3:-"2.10.3"}
RELEASE=${4:-"3"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/libxml2-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://download.gnome.org/sources/libxml2/2.10/libxml2-2.10.3.tar.xz -O $ROOT_DIR/libxml2-$VERSION.tar.xz --no-check-certificate
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE