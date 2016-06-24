#!/bin/bash

set -eu

docker pull centos:7
docker pull centos:6
docker pull fedora:rawhide

for i in 7 6; do
  rm -rf centos${i}.build
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs ./sign.exp
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/x86_64/
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/src/
  cp -f centos${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/x86_64/
  cp -f centos${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/src/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/el${i}/src/
done

rm -rf rawhide.build
make rawhide
find rawhide.build -type f -name '*.rpm' | xargs ./sign.exp
mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/x86_64/ /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/src/
cp -f rawhide.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/x86_64/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/x86_64/
cp -f rawhide.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/src/
createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-2.1/rawhide/src/
