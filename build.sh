#!/bin/bash

set -eu

for dist in el10 el9 el8 eln; do
  rm -rf ${dist}.build
  # Always pull the latest base image (FROM in Containerfile.${dist})
  make ${dist} PULL=always
  find ${dist}.build -type f -name 'h2o-*debug*.rpm' -exec rm -f {} \;
  find ${dist}.build -type f -name '*.rpm' | xargs rpmsign --resign --key-id=C9F367D2

  if [ ${DEPLOY:-0} -ne 0 ]; then
    echo "Deploying ${dist}..."
    if [ ${TEST:-0} -eq 0 ]; then
      DEPLOY_TARGET=h2o-rolling
    else
      DEPLOY_TARGET=h2o-rolling-testing
    fi

    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/${dist}/x86_64/
    mkdir -p /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/${dist}/src/
    cp -f ${dist}.build/RPMS/{x86_64,noarch}/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/${dist}/x86_64/
    cp -f ${dist}.build/SRPMS/h2o-*.rpm /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/${dist}/src/

    pushd /var/www/sites/fetus.jp/rpm.fetus.jp/public_html/${DEPLOY_TARGET}/${dist}
      # Remove old packages
      find x86_64 -type f -name 'h2o-2.*.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +11 | xargs rm -f
      find x86_64 -type f -name 'h2o-doc-2.*.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +11 | xargs rm -f
      find x86_64 -type f -name 'h2o-httpclient-2.*.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +11 | xargs rm -f
      find src -type f -name 'h2o-2.*.src.rpm' -exec stat --format='%Y:%n' {} \; | sort -nr | cut -d: -f2- | tail -n +11 | xargs rm -f

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
