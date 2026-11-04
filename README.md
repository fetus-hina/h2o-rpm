H2O Unofficial RPM package builder
==================================

This provides [H2O](https://h2o.examp1e.net/) RPM spec file and required files
e.g. systemd service etc. to build RPM for RHEL-based 8, 9 and 10 systems.

The package tracks the latest `master` of H2O ("rolling"), and OpenSSL 3.x or
later is statically linked into the binary.

This repository is a fork from [tatsushid/h2o-rpm](https://github.com/tatsushid/h2o-rpm).


## Precompiled RPM files

https://rpm.fetus.jp/h2o-rolling/


## How to build RPM

If you have a docker environment, you can build RPMs by just running

```bash
make
```

If you'd like to build RPM for specific distribution, please run a command like
following

```bash
make el9
```

Now this understands

- el8
- el9
- el10

build options.

Built RPMs are placed under the `elN.build` directory (e.g. `el9.build`).

To remove build artifacts and Docker images, run

```bash
make clean
```


## Updating H2O and OpenSSL

To update the package to the latest H2O revision and OpenSSL release, run

```bash
./prepare.sh
```

This requires Git and Node.js 24 or later. The script

- clones (or updates) the H2O repository into `h2o-repo/`,
- picks the latest commit of H2O `master` and the latest OpenSSL release,
- rewrites the version block at the top of `Makefile`, and
- prepends a new entry to `rpmbuild/SPECS/changelog`. When the H2O revision
  changes, the titles of pull requests merged since the previous revision are
  listed in the entry.

If neither H2O nor OpenSSL has changed, nothing is updated.

Note that `rpmbuild/SPECS/h2o.spec` is generated from `h2o.spec.in` and
`changelog` at build time. Edit `h2o.spec.in` instead of `h2o.spec`.


## Installing RPM

After building, please copy RPM under `*.build` directory to your system and
run

```bash
dnf install h2o-2.3.0-1.git20261102.0.7bbb3e39b.el9.jp3cki.x86_64.rpm
```

Once the installation finishes successfully, you can see a configuration file
at `/etc/h2o/h2o.conf`.

To start h2o, please run

```bash
systemctl enable --now h2o.service
```


## License

This is under MIT License. Please see the
[LICENSE](https://github.com/fetus-hina/h2o-rpm/blob/v2.3.x/LICENSE) file for
details.
