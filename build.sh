#!/bin/bash

set -eu

for i in 9 8; do
  docker pull rockylinux:$i
  rm -rf centos${i}.build
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
  cp -f centos${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  cp -f centos${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
done

for i in 7; do
  docker pull centos:$i
  rm -rf centos${i}.build
  make centos${i}
  find centos${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
  cp -f centos${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
  cp -f centos${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
  createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
done
