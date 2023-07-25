CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-mxml"}
VERSION=${3:-"2.12.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/mxml-2.12.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/michaelrsweet/mxml/archive/refs/tags/v2.12.zip -O $ROOT_DIR/mxml-2.12.zip
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE