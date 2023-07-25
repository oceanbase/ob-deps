CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-lua"}
VERSION=${3:-"5.4.3"}
RELEASE=${4:-"9"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/lua-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget http://www.lua.org/ftp/lua-5.4.3.tar.gz -O $ROOT_DIR/lua-$VERSION.tar.gz --no-check-certificate
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE