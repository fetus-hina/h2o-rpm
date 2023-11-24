H2O Unofficial RPM package builder
==================================

This provides [H2O](https://h2o.examp1e.net/) RPM spec file and required files
e.g. systemd service etc. to build RPM for RHEL/CentOS 7-9 systems.

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
make centos9
```

Now this understands

- centos7
- centos8
- centos9

build options.


## Installing RPM

After building, please copy RPM under `*.build` directory to your system and
run

```bash
dnf install h2o-2.3.0-1.git20231118.3.4f31229e6.el9.jp3cki.x86_64.rpm
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
