H2O_VERSION := 2.3.0-beta2
OPENSSL_VERSION := 1.1.1t

SOURCE_ARCHIVE := v$(H2O_VERSION).tar.gz
OPENSSL_ARCHIVE := openssl-$(OPENSSL_VERSION).tar.gz
TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-23-ossl-package
centos6: IMAGE_NAME := $(IMAGE_NAME)-el6
centos7: IMAGE_NAME := $(IMAGE_NAME)-el7
centos8: IMAGE_NAME := $(IMAGE_NAME)-el8
centos9: IMAGE_NAME := $(IMAGE_NAME)-el9
fedora: IMAGE_NAME := $(IMAGE_NAME)-fc23
rawhide: IMAGE_NAME := $(IMAGE_NAME)-rawhide
opensuse: IMAGE_NAME := $(IMAGE_NAME)-suse13.2
amzn1: IMAGE_NAME := $(IMAGE_NAME)-amzn1
amzn2: IMAGE_NAME := $(IMAGE_NAME)-amzn1

SOURCE_ARCHIVE_URL := https://github.com/h2o/h2o/archive/$(SOURCE_ARCHIVE)
OPENSSL_ARCHIVE_URL := https://www.openssl.org/source/$(OPENSSL_ARCHIVE)

.PHONY: all clean centos6 centos7 centos8 fedora rawhide opensuse amzn1 amzn2

all: centos6 centos7 centos8 centos9 fedora rawhide amzn1 amzn2
centos6: centos6.build
centos7: centos7.build
centos8: centos8.build
centos9: centos9.build
fedora: fedora.build
rawhide: rawhide.build
opensuse: opensuse.build
amzn1: amzn1.build
amzn2: amzn2.build

rpmbuild/SOURCES/$(SOURCE_ARCHIVE):
	curl -fsSL $(SOURCE_ARCHIVE_URL) -o $@

rpmbuild/SOURCES/$(OPENSSL_ARCHIVE):
	curl -fsSL $(OPENSSL_ARCHIVE_URL) -o $@

%.build: rpmbuild/SPECS/h2o.spec rpmbuild/SOURCES/$(SOURCE_ARCHIVE) rpmbuild/SOURCES/$(OPENSSL_ARCHIVE)
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
	docker images | grep -q $(IMAGE_NAME)-el9 && docker rmi $(IMAGE_NAME)-el9 || true
	docker images | grep -q $(IMAGE_NAME)-fc23 && docker rmi $(IMAGE_NAME)-fc23 || true
	docker images | grep -q $(IMAGE_NAME)-rawhide && docker rmi $(IMAGE_NAME)-rawhide || true
	docker images | grep -q $(IMAGE_NAME)-suse13.2 && docker rmi $(IMAGE_NAME)-suse13.2 || true
	docker images | grep -q $(IMAGE_NAME)-amzn1 && docker rmi $(IMAGE_NAME)-amzn1 || true
	docker images | grep -q $(IMAGE_NAME)-amzn2 && docker rmi $(IMAGE_NAME)-amzn2 || true
