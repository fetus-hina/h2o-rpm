%define docroot /var/www

%if 0%{?fedora} >= 15 || 0%{?rhel} >= 7 || 0%{?suse_version} >= 1210
  %global with_systemd 1
%else
  %global with_systemd 0
%endif

%if 0%{?fedora} >= 15 || 0%{?rhel} >= 7
%{?perl_default_filter}
%global __requires_exclude perl\\(VMS|perl\\(Win32|perl\\(Server::Starter
%else
%if 0%{?rhel} == 6
%{?filter_setup:
%filter_requires_in %{_datadir}
%filter_setup
}
%endif
%endif

Summary: H2O - The optimized HTTP/1, HTTP/2 server
Name: h2o
Version: 2.0.0 
Release: 0.beta5.1%{?dist}
URL: https://h2o.examp1e.net/
Source0: https://github.com/h2o/h2o/archive/v2.0.0-beta5.tar.gz
Source1: index.html
Source2: h2o.logrotate
Source3: h2o.init
Source4: h2o.service
Source5: h2o.conf
License: MIT
Group: System Environment/Daemons
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildRequires: cmake >= 2.8, gcc-c++, openssl-devel, pkgconfig
%if 0%{?rhel} == 6
BuildRequires: ruby193, bison
%else
BuildRequires: ruby >= 1.9, bison
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
%setup -q -n h2o-2.0.0-beta5

%build
cmake -DWITH_BUNDLED_SSL=on -DWITH_MRUBY=on -DCMAKE_INSTALL_PREFIX=%{_prefix} .
make %{?_smp_mflags}

# for building shared library
cmake -DWITH_BUNDLED_SSL=on -DWITH_MRUBY=on -DCMAKE_INSTALL_PREFIX=%{_prefix} -DBUILD_SHARED_LIBS=on .
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

%ifarch x86_64
mv $RPM_BUILD_ROOT%{_prefix}/lib/libh2o-evloop.so* \
        $RPM_BUILD_ROOT%{_libdir}/

rm -rf $RPM_BUILD_ROOT%{_prefix}/lib
%endif

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
%else
%{_sysconfdir}/rc.d/init.d/h2o
%endif

%{_bindir}/h2o
%{_datadir}/h2o/annotate-backtrace-symbols
%{_datadir}/h2o/ca-bundle.crt
%{_datadir}/h2o/fastcgi-cgi
%{_datadir}/h2o/fetch-ocsp-response
%{_datadir}/h2o/kill-on-close
%{_datadir}/h2o/mruby
%{_datadir}/h2o/setuidgid
%{_datadir}/h2o/start_server
%{_datadir}/h2o/status/index.html

%{_datadir}/doc

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
%{_libdir}/libh2o-evloop.a
%{_libdir}/libh2o-evloop.so.0.10.0-beta5
%{_libdir}/libh2o-evloop.so.0.10
%{_libdir}/libh2o-evloop.so
%{_libdir}/pkgconfig/libh2o.pc
%{_libdir}/pkgconfig/libh2o-evloop.pc
%{_includedir}/h2o.h
%{_includedir}/h2o

%changelog
* Thu May 26 2016 AIZAWA Hina <hina@bouhime.com> - 2.0.0-0.beta5.1
- Update to 2.0.0-beta5
  - [security fix][http2] fix use-after-free on premature connection close (CVE-2016-4817) #920 (Frederik Deweerdt)
  - [core] fix SIGBUS when temporary disk space is full #910 (Kazuho Oku)
  - [core] add directive for customizing the path of temporary buffer files #911 (Kazuho Oku)
  - [http2] fix potential stall when http2-max-concurrent-requests-per-connection is set to a small number #912 (Kazuho Oku)
  - [http2] refuse push a single resource more than once #903 (Kazuho Oku)
  - [mruby] do not drop link header #913 (Kazuho Oku)
  - [mruby] fix memory leak during initialization #906 (Frederik Deweerdt)
  - [mruby] fix race condition in mruby regex handler #908 (Kazuho Oku)
  - [libh2o] fix crash in h2o_url_stringify #918 (Kazuho OKu)

* Tue May  9 2016 AIZAWA Hina <hina@bouhime.com> - 2.0.0-0.beta4.1
- Update to 2.0.0-beta4
  - [ssl] fix build issue on CentOS 7 (and others that have tolower defined as a macro) #901 (Kazuho Oku)

* Mon May  9 2016 AIZAWA Hina <hina@bouhime.com> - 2.0.0-0.beta3.1
- Update to 2.0.0-beta3
  - [core] configurable server: header #877 (Frederik Deweerdt)
  - [core] fix crash when receiving SIGTERM during start-up #878 (Frederik Deweerdt)
  - [core] spawn the configured number of DNS client threads #880 (Sean McArthur)
  - [access-log][fastcgi][mruby] per-request environment variables #868 (Kazuho Oku)
  - [access-log] fix memory leak during start-up #864 (Frederik Deweerdt)
  - [http2] support for nopush attribute in the link rel=preload header #863 (Satoh Hiroh)
  - [http2] support for push after delegation #866 (Kazuho Oku)
  - [http2] accept capacity-bits attribute of the http2-casper configuration directive #882 (Satoh Hiroh)
  - [http2] ignore push indications made by a pushed response #897 (Kazuho Oku)
  - [proxy] add support for HTTPS #875 (Kazuho Oku)
  - [proxy] add an configuration option to pass through x-forwarded-proto request header #883 (Kazuho Oku)
  - [proxy] log error when upstream connection is unexpectedly closed #895 (Frederik Deweerdt)
  - [ssl] update libressl to 2.2.7 #898 (Kazuho Oku)
  - [ssl] add support for text-based memcache protocol #854 (Kazuho Oku)
  - [ssl] fix memory leak when using TLS resumption with the memcached backend #856 (Kazuho Oku)
  - [ssl] fix "undefined subroutine" error in the OCSP updater #872 (Masayuki Matsuki)
  - [ssl] cap the number of OCSP updaters running concurrently #891 (Kazuho Oku)
  - [libh2o] add API for obtaining the socket descriptor #886 (Frederik Deweerdt)
  - [libh2o] add API to selectively disable automated I/O on reads and writes #890 (Frederik Deweerdt)

* Wed Mar 23 2016 AIZAWA Hina <hina@bouhime.com> - 2.0.0-0.beta2.1
- Update to 2.0.0-beta2
  - [compress] fix potential SEGV when encoding brotli #849 (Kazuho Oku)
  - [compress][expires] refrain from setting redundant `cache-control` tokens #846 (Kazuho Oku)
  - [mruby] add $H2O_ROOT/share/h2o/mruby to the default load path #851 (Kazuho Oku)
  - [status] introduce the status handler #848 (Kazuho Oku)
  - [misc] install examples #850 (James Rouzier)

* Tue Mar 15 2016 AIZAWA Hina <hina@bouhime.com> - 2.0.0-0.beta1.1
- Update to 2.0.0-beta1
  - [core][breaking change] do not automatically append / to path-level configuration #820 (Kazuho Oku)
  - [core] support << in configuration file #786 (Kazuho Oku)
  - [access-log] add directive for logging protocol-specific values #801 (Kazuho Oku)
  - [compress] on-the-fly compression using brotli, as well as directives to tune the compression parameters #802 (Kazuho Oku)
  - [file] file.file directive for mapping specific file #822 (Kazuho Oku)
  - [file] send-compress directive (renamed from send-gzip) to support pre-compressed files using brotli #802 (Kazuho Oku)
  - [file] cache open failures #836 (Kazuho Oku)
  - [http2] avoid memcpy during HPACK huffman encoding #749 (Kazuho Oku)
  - [ssl] support ECDH curves other than P-256 #841 (Kazuho Oku)

* Fri Mar 11 2016 AIZAWA Hina <hina@bouhime.com> - 1.7.1-1
- Update to 1.7.1
  - [core] fix incorrect line no. reported in case of YAML syntax error #785 (Kazuho Oku)
  - [core] fix build issue / memory leak when the poll backend is used #777 #787 (devlearner)
  - [core] when building, repect EXTRA_LIBS passed from command line #793 (Kazuho Oku)
  - [core] fix memory leaks during start-up #792 (Domingo Alvarez Duarte)
  - [core] fix stability issue when receiving a signal #799 (Kazuho Oku)
  - [fastcgi] fix off-by-one buffer overflow #762 (Domingo Alvarez Duarte)
  - [fastcgi][mruby] install missing script files #791 #798 (AIZAWA Hina)
  - [mruby] truncate body to the size specified by content-length #778 (Kazuho Oku)
  - [mruby] fix error when reading a ruby script >= 64K #824 (Domingo Alvarez Duarte)
  - [proxy] fix I/O error when transferring files over 2GB on FreeBSD / OS X #821 #834 (Kazuho Oku)
  - [ssl] bugfix: use of session ticket not disabled even when configured to #819 #835 (Kazuho Oku)
  - [libh2o] provide pkg-config .pc files #743 (OGINO Masanori)
  - [libh2o] include version numbers in the .so filename #794 (Matt Clarkson)
  - [doc] refine documentation #601 #746 #748 #766 #781 #811

* Mon Feb 22 2016 AIZAWA Hina <hina@bouhime.com> - 1.7.0-3
- Install share/h2o/mruby/htpasswd.rb to use basic authentication #798

* Fri Feb 19 2016 AIZAWA Hina <hina@bouhime.com> - 1.7.0-2
- Add fastcgi-cgi support #791

* Fri Feb  5 2016 AIZAWA Hina <hina@bouhime.com> - 1.7.0-1
- Update to 1.7.0
  - [core] support for wildcard hostnames #634 (Kazuho Oku)
  - [core][file] preserve query paramaters upon redirection to a directory #690 (Tatsuhiro Tsujikawa)
  - [core] use uppercase letters in URI-escape sequence #695 (Kazuho Oku)
  - [core] forbid duplicates in hosts section #709 (Kazuho Oku)
  - [fastcgi] add support for CGI #618 (Kazuho Oku)
  - [fastcgi] drop transfer-encoding header #641 (Kazuho Oku)
  - [file] fix a bug that caused file.mime.addtypes to fail setting the attributes of a content-type #731 (Kazuho Oku)
  - [http2] fix broken PUSH_PROMISE frames being sent under high pressure #734 #736 (Kazuho Oku)
  - [mruby] provide env["rack.input"] #515 #638 #644 (Masayoshi Takahashi, Kazuho Oku)
  - [mruby] HTTP client API #637 #643 (Kazuho Oku)
  - [mruby] dump the ruby source on error #631 (Kazuho Oku)
  - [mruby] provide access to $H2O_ROOT #629 (Kazuho Oku)
  - [mruby] change mrb_int to 64-bit on 64-bit systems #639 (Kazuho Oku)
  - [mruby] concatenate request headers having same name #666 (Kazuho Oku)
  - [mruby] bundle mruby-errno, mruby-file-stat #675 (Kazuho Oku)
  - [mruby] refrain from building mruby handler by default if mkmf (part of ruby dev files) is not found #710 (Kazuho Oku)
  - [proxy] detect upstream close of pooled socket before reuse #679 (Kazuho Oku)
  - [reproxy] add support for relative URI #712 (Kazuho Oku)
  - [ssl] turn on neverbleed by default #633 (Kazuho Oku)
  - [libh2o] fix memory leaks during destruction #724 (greatwar)
  - [libh2o] simplify vector operations #715 #735 (Domingo Alvarez Duarte)
  - [misc] support basic authentication using .htpasswd #624 (Kazuho Oku)
  - [misc] fix build error when an older version of H2O is installed aside an external dependency #718 #722 #736 (Kazuho Oku)

* Tue Jan 26 2016 AIZAWA Hina <hina@bouhime.com> - 1.6.3-1
- Update to 1.6.3

* Wed Jan 13 2016 Tatsushi Demachi <tdemachi@gmail.com> - 1.6.2-1
- Update to 1.6.2

* Sat Dec 19 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.6.1-1
- Update to 1.6.1

* Thu Dec  5 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.6.0-1
- Update to 1.6.0
- Remove patch by upstream fix

* Thu Nov 12 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.5.4-1
- Update to 1.5.4

* Sat Nov  7 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.5.3-1
- Update to 1.5.3

* Mon Nov  2 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.5.2-2
- Add mruby support
- Fix official URL

* Tue Oct 20 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.5.2-1
- Update to 1.5.2

* Wed Oct  9 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.5.0-2
- Add patch to fix CMake version issue for CentOS 7 build

* Thu Oct  8 2015 Donald Stufft <donald@stufft.io> - 1.5.0-1
- Update to 1.5.0

* Wed Sep 16 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.4.5-1
- Update to 1.4.5

* Tue Aug 18 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.4.4-1
- Update to 1.4.4

* Mon Aug 17 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.4.3-1
- Update to 1.4.3

* Wed Jul 29 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.4.2-1
- Update to 1.4.2

* Thu Jul 23 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.4.1-1
- Update to 1.4.1

* Tue Jun 23 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.3.1-4
- Add OpenSUSE support

* Mon Jun 22 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.3.1-3
- Fix logrotate

* Sun Jun 21 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.3.1-2
- Add fedora support

* Sat Jun 20 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.3.1-1
- Update to 1.3.1

* Thu Jun 18 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.3.0-1
- Update to 1.3.0
- Move library and headers to devel sub-package

* Fri May 22 2015 Tatsushi Demachi <tdemachi@gmail.com> - 1.2.0-1
- Initial package release
