# ---- BEGIN VERSION BLOCK ----
H2O_GIT_DATE := 20260413
H2O_GIT_DATE_REBUILD := 0
H2O_GIT_REF := df7915db85501798de7b104085f4ee790ba20a45
H2O_GIT_REF_SHORT := df7915db8
OPENSSL_VERSION := 3.6.2
# ---- END VERSION BLOCK ----

SOURCE_ARCHIVE := h2o-$(H2O_GIT_REF).tar.gz
TARGZ_FILE := h2o.tar.gz
IMAGE_NAME := h2o-23-package
el8: IMAGE_NAME := $(IMAGE_NAME)-el8
el9: IMAGE_NAME := $(IMAGE_NAME)-el9
el10: IMAGE_NAME := $(IMAGE_NAME)-el10

.PHONY: all el8 el9 el10
all: el8 el9 el10
el8: el8.build
el9: el9.build
el10: el10.build

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
	docker images | grep -q $(IMAGE_NAME)-el8 && docker rmi $(IMAGE_NAME)-el8 || true
	docker images | grep -q $(IMAGE_NAME)-el9 && docker rmi $(IMAGE_NAME)-el9 || true
	docker images | grep -q $(IMAGE_NAME)-el10 && docker rmi $(IMAGE_NAME)-el10 || true
