#!/bin/bash

set -eu

for i in 7 6; do
  docker pull centos:$i
  rm -rf centos${i}.build
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs ./sign.exp
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/x86_64/
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/src/
  cp -f centos${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/x86_64/
  cp -f centos${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/src/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/el${i}/src/
done

docker pull fedora:rawhide
rm -rf rawhide.build
make rawhide
find rawhide.build -type f -name '*.rpm' | xargs ./sign.exp
mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/x86_64/ /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/src/
cp -f rawhide.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/x86_64/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/x86_64/
cp -f rawhide.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/src/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/rawhide/src/

for i in 1 2; do
  docker pull amazonlinux:$i
  rm -rf amzn${i}.build
  make amzn${i}
  find amzn${i}.build -type f -name '*.rpm' | xargs ./sign.exp
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/x86_64/
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/src/
  cp -f amzn${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/x86_64/
  cp -f amzn${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/src/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-openssl-2.3/amzn${i}/src/
done
