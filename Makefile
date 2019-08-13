SOURCE_ARCHIVE := h2o-master.tar.gz
LIBRESSL_ARCHIVE := libressl.tar.gz

TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-nightly-package

centos7: IMAGE_NAME := $(IMAGE_NAME)-el7
centos8: IMAGE_NAME := $(IMAGE_NAME)-el8

.PHONY: all clean centos7 centos8

all: h2o-info.mk libressl-info.mk centos7 centos8
centos7: centos7.build
centos8: centos8.build

repo:
	git clone --depth=1 https://github.com/h2o/h2o.git $@

libressl-repo:
	git clone --depth=1 https://github.com/libressl-portable/portable.git $@

libressl-repo/openbsd: libressl-repo
	git clone --depth=1 https://github.com/libressl-portable/openbsd.git $@

h2o-info.mk: repo
	./util/h2o-info.js > $@

rpmbuild/SOURCES/$(SOURCE_ARCHIVE): repo
	tar -zcvf $@ $<

rpmbuild/SOURCES/$(LIBRESSL_ARCHIVE): libressl-repo libressl-repo/openbsd
	tar -zcvf $@ $<

rpmbuild/SPECS/h2o.spec: rpmbuild/SPECS/h2o.spec.in h2o-info.mk
	cat rpmbuild/SPECS/h2o.spec.in \
		| sed \
			-e s/__RPM_REVISION__/$(RPM_REVISION)/ \
			-e s/__H2O_VERSION__/$(H2O_VERSION)/ \
			-e s/__H2O_VERSION_WO_DEV__/$(H2O_VERSION_WO_DEV)/ \
			-e s/__LIBH2O_VERSION__/$(LIBH2O_VERSION)/ \
			-e s/__LIBH2O_SO_VERSION__/$(LIBH2O_SO_VERSION)/ \
		> $@

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
	rm -rf \
		*.build \
		*.build.bak \
		Dockerfile \
		h2o-info.mk \
		libressl-repo \
		repo \
		rpmbuild/SOURCES/$(LIBRESSL_ARCHIVE) \
		rpmbuild/SOURCES/$(SOURCE_ARCHIVE) \
		rpmbuild/SPECS/h2o.spec \
		tmp
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true

include h2o-info.mk
