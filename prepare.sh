#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

pushd $SCRIPT_DIR
  # prepare h2o-repo
  if [ ! -e h2o-repo ]; then
    git clone https://github.com/h2o/h2o.git h2o-repo
  else
    pushd h2o-repo
      git checkout master
      git clean -fdx
      git fetch origin --prune
      git reset --hard origin/master
    popd
  fi

  npm ci
  npx tsx prepare.ts
popd
