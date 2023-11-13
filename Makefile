# ---- BEGIN VERSION BLOCK ----
H2O_GIT_DATE := 20231108
H2O_GIT_DATE_REBUILD := 0
H2O_GIT_REF := b15937e082e5ec70bcee3fd699897fd670b3e0e0
H2O_GIT_REF_SHORT := b15937e08
OPENSSL_VERSION := 3.1.4
# ---- END VERSION BLOCK ----

SOURCE_ARCHIVE := h2o-$(H2O_GIT_REF).tar.gz
TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-23-package
centos7: IMAGE_NAME := $(IMAGE_NAME)-el7
centos8: IMAGE_NAME := $(IMAGE_NAME)-el8
centos8: IMAGE_NAME := $(IMAGE_NAME)-el9

.PHONY: all centos7 centos8 centos9
all: centos7 centos8 centos9
centos7: centos7.build
centos8: centos8.build
centos9: centos9.build

rpmbuild/SOURCES/$(SOURCE_ARCHIVE):
	curl -fsSL https://github.com/h2o/h2o/archive/$(H2O_GIT_REF).tar.gz -o $@

rpmbuild/SOURCES/h2o-openssl-$(OPENSSL_VERSION).tar.gz:
	curl -fsSL \
		-o $@ \
		https://github.com/openssl/openssl/releases/download/openssl-$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION).tar.gz

.PHONY: rpmbuild/SPECS/h2o.spec
rpmbuild/SPECS/h2o.spec: rpmbuild/SPECS/h2o.spec.in rpmbuild/SPECS/changelog
	cat $< | \
		sed -e "s|@H2O_GIT_DATE@|$(H2O_GIT_DATE)|g" | \
		sed -e "s|@H2O_GIT_DATE_REBUILD@|$(H2O_GIT_DATE_REBUILD)|g" | \
		sed -e "s|@H2O_GIT_REF@|$(H2O_GIT_REF)|g" | \
		sed -e "s|@H2O_GIT_REF_SHORT@|$(H2O_GIT_REF_SHORT)|g" | \
		sed -e "s|@OPENSSL_VERSION@|$(OPENSSL_VERSION)|g" \
			> $@
	cat rpmbuild/SPECS/changelog >> $@

%.build: rpmbuild/SPECS/h2o.spec rpmbuild/SOURCES/$(SOURCE_ARCHIVE) rpmbuild/SOURCES/h2o-openssl-$(OPENSSL_VERSION).tar.gz
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

.PHONY: clean
clean:
	rm -rf *.build.bak *.build tmp Dockerfile
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true
	docker images | grep -q $(IMAGE_NAME)-el8 && docker rmi $(IMAGE_NAME)-el8 || true
	docker images | grep -q $(IMAGE_NAME)-el9 && docker rmi $(IMAGE_NAME)-el9 || true
