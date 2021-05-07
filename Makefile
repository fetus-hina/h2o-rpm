H2O_VERSION := 2.3.0-beta2
LIBRESSL_VERSION := 3.3.3

SOURCE_ARCHIVE := v$(H2O_VERSION).tar.gz
LIBRESSL_ARCHIVE := libressl-$(LIBRESSL_VERSION).tar.gz
TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-23-package
centos6: IMAGE_NAME := $(IMAGE_NAME)-el6
centos7: IMAGE_NAME := $(IMAGE_NAME)-el7
centos8: IMAGE_NAME := $(IMAGE_NAME)-el8
fedora: IMAGE_NAME := $(IMAGE_NAME)-fc23
rawhide: IMAGE_NAME := $(IMAGE_NAME)-rawhide
opensuse: IMAGE_NAME := $(IMAGE_NAME)-suse13.2
amzn1: IMAGE_NAME := $(IMAGE_NAME)-amzn1
amzn2: IMAGE_NAME := $(IMAGE_NAME)-amzn1

.PHONY: all clean centos6 centos7 fedora rawhide opensuse amzn1 amzn2

all: centos6 centos7 centos8 fedora rawhide amzn1 amzn2
centos6: centos6.build
centos7: centos7.build
centos8: centos8.build
fedora: fedora.build
rawhide: rawhide.build
opensuse: opensuse.build
amzn1: amzn1.build
amzn2: amzn2.build

rpmbuild/SOURCES/$(SOURCE_ARCHIVE):
	curl -fSL https://github.com/h2o/h2o/archive/$(SOURCE_ARCHIVE) -o $@

rpmbuild/SOURCES/$(LIBRESSL_ARCHIVE):
	curl -fSL https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$(LIBRESSL_VERSION).tar.gz -o $@

%.build: rpmbuild/SPECS/h2o.spec rpmbuild/SOURCES/$(SOURCE_ARCHIVE) rpmbuild/SOURCES/$(LIBRESSL_ARCHIVE)
	[ -d $@.bak ] && rm -rf $@.bak || :
	[ -d $@ ] && mv $@ $@.bak || :
	cp Dockerfile.$* Dockerfile
	tar -czf - Dockerfile rpmbuild | docker build -t $(IMAGE_NAME) -
	docker run --name $(IMAGE_NAME)-tmp $(IMAGE_NAME)
	mkdir -p tmp
	docker wait $(IMAGE_NAME)-tmp
	docker cp $(IMAGE_NAME)-tmp:/tmp/$(TARGZ_FILE) tmp
	docker rm $(IMAGE_NAME)-tmp
	mkdir $@
	tar -xzf tmp/$(TARGZ_FILE) -C $@
	rm -rf tmp Dockerfile
	docker images | grep -q $(IMAGE_NAME) && docker rmi $(IMAGE_NAME) || true

clean:
	rm -rf *.build.bak *.build tmp Dockerfile
	docker images | grep -q $(IMAGE_NAME)-el6 && docker rmi $(IMAGE_NAME)-el6 || true
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true
	docker images | grep -q $(IMAGE_NAME)-el8 && docker rmi $(IMAGE_NAME)-el8 || true
	docker images | grep -q $(IMAGE_NAME)-fc23 && docker rmi $(IMAGE_NAME)-fc23 || true
	docker images | grep -q $(IMAGE_NAME)-rawhide && docker rmi $(IMAGE_NAME)-rawhide || true
	docker images | grep -q $(IMAGE_NAME)-suse13.2 && docker rmi $(IMAGE_NAME)-suse13.2 || true
	docker images | grep -q $(IMAGE_NAME)-amzn1 && docker rmi $(IMAGE_NAME)-amzn1 || true
	docker images | grep -q $(IMAGE_NAME)-amzn2 && docker rmi $(IMAGE_NAME)-amzn2 || true
