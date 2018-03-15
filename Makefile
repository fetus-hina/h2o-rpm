SOURCE_ARCHIVE := h2o-master.tar.gz

TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-nightly-package

centos7: IMAGE_NAME := $(IMAGE_NAME)-el7

.PHONY: all clean centos7

all: h2o-info.mk libressl-info.mk centos7
centos7: centos7.build

repo:
	git clone https://github.com/h2o/h2o.git $@

h2o-info.mk: repo
	./util/h2o-info.js > $@

libressl-info.mk:
	./util/libressl-info.js > $@

rpmbuild/SOURCES/$(SOURCE_ARCHIVE): repo
	tar -zcv --exclude-vcs -f $@ $<

rpmbuild/SPECS/h2o.spec: rpmbuild/SPECS/h2o.spec.in h2o-info.mk libressl-info.mk
	cat rpmbuild/SPECS/h2o.spec.in \
		| sed \
			-e s/__RPM_REVISION__/$(RPM_REVISION)/ \
			-e s/__H2O_VERSION__/$(H2O_VERSION)/ \
			-e s/__H2O_VERSION_WO_DEV__/$(H2O_VERSION_WO_DEV)/ \
			-e s/__LIBH2O_VERSION__/$(LIBH2O_VERSION)/ \
			-e s/__LIBH2O_SO_VERSION__/$(LIBH2O_SO_VERSION)/ \
			-e s/__LIBRESSL_VERSION__/$(LIBRESSL_VERSION)/ \
		> $@

%.build: rpmbuild/SPECS/h2o.spec rpmbuild/SOURCES/$(SOURCE_ARCHIVE)
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
	rm -rf *.build.bak *.build tmp Dockerfile \
		h2o-info.mk libressl-info.mk \
		repo rpmbuild/SPECS/h2o.spec
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true

include h2o-info.mk
include libressl-info.mk
