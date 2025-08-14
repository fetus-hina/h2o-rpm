#!/bin/bash

set -eu

for i in 10 9 8; do
  if [ $i -eq 10 ]; then
    DISTRO=almalinux
  else
    DISTRO=rockylinux
  fi
  docker pull ${DISTRO}:${i}
  rm -rf el${i}.build
  make el${i}
  find el${i}.build -type f -name 'h2o-debug*.rpm' -exec rm -f {} \;
  find el${i}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2

  if [ ${DEPLOY:-0} -ne 0 ]; then
    echo "Deploying el${i}..."
    if [ ${TEST:-0} -eq 0 ]; then
      DEPLOY_TARGET=h2o-rolling
    else
      DEPLOY_TARGET=h2o-rolling-testing
    fi

    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/el${i}/x86_64/
    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/el${i}/src/
    cp -f el${i}.build/RPMS/x86_64/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/el${i}/x86_64/
    cp -f el${i}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/el${i}/src/

    pushd /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/el${i}
      # Remove old packages
      find x86_64 -type f -name 'h2o-2.*.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +6 | xargs rm -f
      find x86_64 -type f -name 'h2o-doc-2.*.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +6 | xargs rm -f
      find src -type f -name 'h2o-2.*.src.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +6 | xargs rm -f

      for dir in x86_64 src; do
        pushd ${dir}
          createrepo .

          for hashfunc in md5sum sha1sum sha256sum; do
            env ${hashfunc} *.rpm > ${hashfunc}.txt
          done
        popd
      done
    popd
  fi
done
