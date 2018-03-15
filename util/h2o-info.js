#!/usr/bin/env node

const path = require('path');

const gitRevision = path => {
  const ret = require('child_process').execSync(
    "git log --pretty=format:'%h' -n 1",
    {
      cwd: path,
      shell: '/bin/bash',
    }
  );
  return ret;
};

const rpm_revision = (() => {
  // {{{
  const zero = num => num < 10 ? "0" + String(num) : String(num);
  const date = new Date();
  const year = date.getFullYear();
  const month = zero(date.getMonth() + 1);
  const day = zero(date.getDate());
  const revision = gitRevision(path.join(__dirname, '..', 'repo'));
  return `0.nightly${year}${month}${day}.git${revision}`;
  // }}}
})();

const h2o_version = (() => {
  // {{{
  const file = require('fs').readFileSync(path.join(__dirname, '..', 'repo', 'CMakeLists.txt'));
  const get = tag => {
    const regex = new RegExp('^SET\\(' + tag + ' "(.*?)"\\)', 'm');
    const match = regex.exec(String(file));
    if (!match) {
      throw new Error();
    }
    return match[1];
  };

  const major = get('VERSION_MAJOR');
  const minor = get('VERSION_MINOR');
  const patch = get('VERSION_PATCH');
  const pre   = get('VERSION_PRERELEASE');

  return `${major}.${minor}.${patch}${pre}`;
  // }}}
})();

const libh2o_version = (() => {
  // {{{
  const file = require('fs').readFileSync(path.join(__dirname, '..', 'repo', 'CMakeLists.txt'));
  const get = tag => {
    const regex = new RegExp('^SET\\(' + tag + ' "(.*?)"\\)', 'm');
    const match = regex.exec(String(file));
    if (!match) {
      throw new Error();
    }
    return match[1];
  };

  const major = get('LIBRARY_VERSION_MAJOR');
  const minor = get('LIBRARY_VERSION_MINOR');
  const patch = get('LIBRARY_VERSION_PATCH');
  const pre   = get('VERSION_PRERELEASE');

  return `${major}.${minor}.${patch}${pre}`;
  // }}}
})();

const libh2o_so_version = (() => {
  // {{{
  const file = require('fs').readFileSync(path.join(__dirname, '..', 'repo', 'CMakeLists.txt'));
  const get = tag => {
    const regex = new RegExp('^SET\\(' + tag + ' "(.*?)"\\)', 'm');
    const match = regex.exec(String(file));
    if (!match) {
      throw new Error();
    }
    return match[1];
  };

  const major = get('LIBRARY_VERSION_MAJOR');
  const minor = get('LIBRARY_VERSION_MINOR');

  return `${major}.${minor}`;
  // }}}
})();

console.log(`RPM_REVISION := ${rpm_revision}`);
console.log(`H2O_VERSION := ${h2o_version}`);
console.log('H2O_VERSION_WO_DEV := ' + h2o_version.replace(/-.*$/, ''));
console.log(`LIBH2O_VERSION := ${libh2o_version}`);
console.log(`LIBH2O_SO_VERSION := ${libh2o_so_version}`);
