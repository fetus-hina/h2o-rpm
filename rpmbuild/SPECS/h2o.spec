%define docroot /var/www

%if 0%{?fedora} >= 15 || 0%{?rhel} >= 7 || 0%{?suse_version} >= 1210 || 0%{?amzn} >= 2
  %global with_systemd 1
%else
  %global with_systemd 0
%endif

%if 0%{?fedora} >= 15 || 0%{?rhel} >= 7 || 0%{?amzn} >= 2
%{?perl_default_filter}
%global __requires_exclude perl\\(VMS|perl\\(Win32|perl\\(Server::Starter
%else
%if 0%{?rhel} == 6 || 0%{?amzn} == 1
%{?filter_setup:
%filter_requires_in %{_datadir}
%filter_setup
}
%endif
%endif

%define libressl_version 2.7.3

Summary: H2O - The optimized HTTP/1, HTTP/2 server
Name: h2o
Version: 2.3.0
Release: 0.1.bata1.1%{?dist}
URL: https://h2o.examp1e.net/
Source0: https://github.com/h2o/h2o/archive/v2.3.0-beta1.tar.gz
Source1: index.html
Source2: h2o.logrotate
Source3: h2o.init
Source4: h2o.service
Source5: h2o.conf
Source6: h2o-tmpfile.conf
Source100: libressl-%{libressl_version}.tar.gz
License: MIT
Group: System Environment/Daemons
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildRequires: cmake >= 2.8, openssl-devel, pkgconfig
%if 0%{?rhel} == 6
BuildRequires: devtoolset-7-gcc-c++, ruby193, bison
%else
BuildRequires: gcc-c++, ruby >= 1.9, bison
%endif
Requires: openssl, perl
%if %{with_systemd}
%if 0%{?suse_version}
BuildRequires: systemd-rpm-macros
%{?systemd_requires}
%else
BuildRequires: systemd-units
Requires(preun): systemd
Requires(postun): systemd
Requires(post): systemd
%endif
%else
Requires: initscripts >= 8.36
Requires(post): chkconfig
%endif

%description
H2O is a very fast HTTP server written in C. It can also be used
as a library.

%package devel
Group: Development/Libraries
Summary: Development interfaces for H2O
Requires: openssl-devel
Requires: h2o = %{version}-%{release}

%description devel
The h2o-devel package provides H2O library and its header files
which allow you to build your own software using H2O.

%prep
%setup -q -n h2o-%{version}-beta1
%define libressl_build %{_tmppath}/%{name}-%{version}-%{release}-libressl-build
mkdir -p %{libressl_build}
cat %{SOURCE100} | tar -zx -C %{libressl_build} --strip-components=1 -f -

%build
# build LibreSSL
pushd %{libressl_build}
%define libressl_root %{_tmppath}/%{name}-%{version}-%{release}-libressl-root
./configure --disable-shared --prefix=%{libressl_root} --libdir=%{libressl_root}/lib --with-pic
make %{?_smp_mflags}
make install
popd

# Build H2O
cmake \
    -DWITH_BUNDLED_SSL=off \
    -DWITH_MRUBY=on \
    -DCMAKE_C_FLAGS="-std=gnu99" \
    -DCMAKE_CXX_FLAGS="-std=gnu++0x" \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INCLUDE_PATH=%{libressl_root}/include \
    -DCMAKE_LIBRARY_PATH=%{libressl_root}/lib \
    -DCMAKE_EXE_LINKER_FLAGS_INIT="-lrt" \
    -DCMAKE_SHARED_LINKER_FLAGS_INIT="-lrt" \
    .
make %{?_smp_mflags}

# for building shared library
cmake \
    -DWITH_BUNDLED_SSL=off \
    -DWITH_MRUBY=on \
    -DCMAKE_C_FLAGS="-std=gnu99" \
    -DCMAKE_CXX_FLAGS="-std=gnu++0x" \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INCLUDE_PATH=%{libressl_root}/include \
    -DCMAKE_LIBRARY_PATH=%{libressl_root}/lib \
    -DBUILD_SHARED_LIBS=on \
    -DCMAKE_EXE_LINKER_FLAGS_INIT="-lrt" \
    -DCMAKE_SHARED_LINKER_FLAGS_INIT="-lrt" \
    .
make %{?_smp_mflags}

%if !%{with_systemd}
sed -i -e 's,\( *\).*systemctl.* >,\1/sbin/service h2o reload >,' %{SOURCE2}
%endif

%if 0%{?suse_version}
sed -i -e '/localhost:443/,/file.dir/s/^/#/' -e 's|\(file.dir: \).*|\1/srv/www/htdocs|' %{SOURCE5}
%endif

%install
rm -rf $RPM_BUILD_ROOT

make DESTDIR=$RPM_BUILD_ROOT install

mkdir -p $RPM_BUILD_ROOT/%{_libdir}

install -m 644 -p libh2o-evloop.a \
        $RPM_BUILD_ROOT%{_libdir}/libh2o-evloop.a

mkdir -p $RPM_BUILD_ROOT/%{_libdir}/pkgconfig
install -m 644 -p libh2o.pc \
        $RPM_BUILD_ROOT%{_libdir}/pkgconfig/libh2o.pc

install -m 644 -p libh2o-evloop.pc \
        $RPM_BUILD_ROOT%{_libdir}/pkgconfig/libh2o-evloop.pc

mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/h2o
install -m 644 -p $RPM_SOURCE_DIR/h2o.conf \
        $RPM_BUILD_ROOT%{_sysconfdir}/h2o/h2o.conf

%if 0%{?suse_version} == 0
# docroot
mkdir -p $RPM_BUILD_ROOT%{docroot}/html
install -m 644 -p $RPM_SOURCE_DIR/index.html \
        $RPM_BUILD_ROOT%{docroot}/html/index.html
%endif

# Set up /var directories
mkdir -p $RPM_BUILD_ROOT%{_localstatedir}/log/h2o

%if %{with_systemd}
# Install systemd service files
mkdir -p $RPM_BUILD_ROOT%{_unitdir}
install -m 644 -p $RPM_SOURCE_DIR/h2o.service \
	$RPM_BUILD_ROOT%{_unitdir}/h2o.service

mkdir -p $RPM_BUILD_ROOT/run/h2o
mkdir -p $RPM_BUILD_ROOT%{_prefix}/lib/tmpfiles.d
install -m 644 -p $RPM_SOURCE_DIR/h2o-tmpfile.conf \
        $RPM_BUILD_ROOT%{_prefix}/lib/tmpfiles.d/h2o.conf
%else
# install SYSV init stuff
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/rc.d/init.d
install -m 755 -p $RPM_SOURCE_DIR/h2o.init \
	$RPM_BUILD_ROOT%{_sysconfdir}/rc.d/init.d/h2o

mkdir -p $RPM_BUILD_ROOT%{_localstatedir}/run/h2o
%endif

# install log rotation stuff
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d
install -m 644 -p $RPM_SOURCE_DIR/h2o.logrotate \
	$RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/h2o

%define sslcert %{_sysconfdir}/pki/tls/certs/localhost.crt
%define sslkey %{_sysconfdir}/pki/tls/private/localhost.key

%pre
%if %{with_systemd} && 0%{?suse_version}
%service_add_pre h2o.service
%endif

%post
%if %{with_systemd}
%if 0%{?suse_version}
%service_add_post h2o.service
%else
%systemd_post h2o.service
%endif
%else
# Register the h2o service
/sbin/chkconfig --add h2o
%endif

%if 0%{?suse_version} == 0
umask 037
if [ -f %{sslkey} -o -f %{sslcert} ]; then
   exit 0
fi

if [ ! -f %{sslkey} ] ; then
%{_bindir}/openssl genrsa -rand /proc/apm:/proc/cpuinfo:/proc/dma:/proc/filesystems:/proc/interrupts:/proc/ioports:/proc/pci:/proc/rtc:/proc/uptime 2048 > %{sslkey} 2> /dev/null
fi

FQDN=`hostname`
if [ "x${FQDN}" = "x" ]; then
   FQDN=localhost.localdomain
fi

if [ ! -f %{sslcert} ] ; then
cat << EOF | %{_bindir}/openssl req -new -key %{sslkey} \
         -x509 -sha256 -days 365 -set_serial $RANDOM -extensions v3_req \
         -out %{sslcert} 2>/dev/null
--
SomeState
SomeCity
SomeOrganization
SomeOrganizationalUnit
${FQDN}
root@${FQDN}
EOF
fi

if [ -f %{sslkey} ]; then
   chgrp nobody %{sslkey}
fi

if [ -f %{sslcert} ]; then
   chgrp nobody %{sslcert}
fi
%endif

%preun
%if %{with_systemd}
%if 0%{?suse_version}
%service_del_preun h2o.service
%else
%systemd_preun h2o.service
%endif
%else
if [ $1 = 0 ]; then
	/sbin/service h2o stop > /dev/null 2>&1
	/sbin/chkconfig --del h2o
fi
%endif

%postun
%if %{with_systemd}
%if 0%{?suse_version}
%service_del_postun h2o.service
%else
%systemd_postun
%endif
if [ $1 -ge 1 ]; then
    systemctl status h2o >/dev/null 2>&1 || exit 0
    systemctl reload h2o >/dev/null 2>&1 || echo "Binary upgrade failed, please check h2o's error.log"
fi
%else
if [ $1 -ge 1 ]; then
    service h2o status >/dev/null 2>&1 || exit 0
    service h2o reload >/dev/null 2>&1 || echo "Binary upgrade failed, please check h2o's error.log"
fi
%endif

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)

%dir %{_sysconfdir}/h2o
%config(noreplace) %{_sysconfdir}/h2o/h2o.conf
%config(noreplace) %{_sysconfdir}/logrotate.d/h2o

%if %{with_systemd}
%{_unitdir}/h2o.service
%{_prefix}/lib/tmpfiles.d/h2o.conf
%else
%{_sysconfdir}/rc.d/init.d/h2o
%endif

%{_bindir}/h2o
%{_datadir}/h2o
%{_datadir}/doc/h2o
%{_datadir}/man

%if 0%{?suse_version} == 0
%dir %{docroot}
%dir %{docroot}/html
%config(noreplace) %{docroot}/html/index.html
%endif

%if %{with_systemd}
%attr(0770,root,nobody) %dir /run/h2o
%else
%attr(0710,root,nobody) %dir %{_localstatedir}/run/h2o
%endif
%attr(0700,root,root) %dir %{_localstatedir}/log/h2o

%files devel
%{_libdir}/libh2o-evloop.*
%{_libdir}/pkgconfig/libh2o*.pc
%{_includedir}/h2o.h
%{_includedir}/h2o

%changelog
* Sun Jun  3 2018 AIZAWA Hina <hina@bouhime.com> - 2.3.0-0.1.bata1.1
- Update to v2.3.0 beta 1

* Sun Jun  3 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.5-2
- Fix build issue for CentOS 6 systems.

* Sat Jun  2 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.5-1
- Update to 2.2.5

* Sun May  6 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.4-7
- Rebuild with LibreSSL 2.7.3

* Fri Apr 13 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.4-6
- Rebuild with LibreSSL 2.7.2

* Wed Mar 28 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.4-5
- Fix build issue on CentOS 6 system

* Sun Mar 25 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.4-4
- Rebuild with LibreSSL 2.7.1

* Fri Mar 23 2018 AIZAWA Hina <hina@bouhime.com> - 2.2.4-3
- Rebuild with LibreSSL 2.7.0

* Fri Dec 22 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.4-2
- Rebuild with LibreSSL 2.6.4

* Fri Dec 15 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.4-1
- Remove additional patches
- Update to 2.2.4

* Mon Nov 13 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.3-4
- Add patch for https://github.com/h2o/h2o/issues/1463

* Wed Nov  8 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.3-3
- Rebuild with LibreSSL 2.6.3

* Fri Oct 20 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.3-2
- Add patch for https://github.com/h2o/h2o/issues/1464

* Thu Oct 19 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.3-1
- Update to 2.2.3

* Thu Oct 12 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.2-5
- Rebuild with LibreSSL 2.6.2

* Thu Sep 14 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.2-4
- Rebuild with LibreSSL 2.6.1

* Sat Jul 15 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.2-3
- Rebuild with LibreSSL 2.6.0

* Wed May  3 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.2-2
- Rebuild with LibreSSL 2.5.4

* Sun Apr 23 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.2-1
- Update to 2.2.2 (2.2.1 is broken. skipped it)

* Wed Apr 12 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-2
- Rebuild with LibreSSL 2.5.3

* Wed Apr  5 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-1
- Update to 2.2.0

* Sun Apr  2 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-0.beta3.2
- Rebuild with LibreSSL 2.5.2

* Wed Mar 22 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-0.beta3.1
- Update to 2.2.0-beta3

* Tue Mar 14 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-0.beta2.1
- Update to 2.2.0-beta2

* Tue Feb 28 2017 AIZAWA Hina <hina@bouhime.com> - 2.2.0-0.beta1.1
- Update to 2.2.0-beta1
