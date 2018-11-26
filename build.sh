#!/bin/bash

set -eu

SCRIPT_DIR=$(cd $(dirname $0);pwd)
REPO_DIR=${SCRIPT_DIR}/repo

cd $SCRIPT_DIR

rm -rf $REPO_DIR h2o-info.mk libressl-info.mk

docker pull centos:7
rm -rf centos7.build
make clean
make centos7
find centos7.build -type f -name '*.rpm' | xargs ./sign.exp
mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/x86_64/
mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/src/
find /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly -type f -name '*.rpm' -mtime +6 | xargs rm -f
cp -f centos7.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/x86_64/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/x86_64/
cp -f centos7.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/src/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-nightly/el7/src/
