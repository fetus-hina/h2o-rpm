#!/bin/bash

set -eu

for i in 9 8 7; do
  if [ $i -lt 8 ]; then
    DISTRO=centos
  else
    DISTRO=rockylinux
  fi
  docker pull ${DISTRO}:${i}
  rm -rf centos${i}.build
  make centos${i}
  find centos${i}.build -type f -name 'h2o-debug*.rpm' -exec rm -f {} \;
  find centos${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2

  if [ ${DEPLOY:-0} -ne 0 ]; then
    echo "Deploying el${i}..."

    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
    cp -f centos${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
    cp -f centos${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/
    createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/x86_64/
    createrepo /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}/src/

    pushd /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/h2o-rolling/el${i}
      for dir in x86_64 src; do
        pushd ${dir}
          for hashfunc in md5sum sha1sum sha256sum; do
            env ${hashfunc} *.rpm > ${hashfunc}.txt
          done
        popd
      done
    popd
  fi
done
