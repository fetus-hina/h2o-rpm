# ---- BEGIN VERSION BLOCK ----
H2O_GIT_DATE := 20261109
H2O_GIT_DATE_REBUILD := 0
H2O_GIT_REF := 2fd73eaf1a30d4a6d2ed8089f9313e46a08c8f1e
H2O_GIT_REF_SHORT := 2fd73eaf1
OPENSSL_VERSION := 4.1.0
# ---- END VERSION BLOCK ----

SOURCE_ARCHIVE := h2o-$(H2O_GIT_REF).tar.gz
PODMAN ?= podman
# Base image pull policy for "podman build" (missing / newer / always / never)
PULL ?= missing
IMAGE_NAME := h2o-23-package
el8: IMAGE_NAME := $(IMAGE_NAME)-el8
el9: IMAGE_NAME := $(IMAGE_NAME)-el9
el10: IMAGE_NAME := $(IMAGE_NAME)-el10
eln: IMAGE_NAME := $(IMAGE_NAME)-eln

.PHONY: all el8 el9 el10 eln
all: el8 el9 el10 eln
el8: el8.build
el9: el9.build
el10: el10.build
eln: eln.build

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
	$(PODMAN) build --pull=$(PULL) -t $(IMAGE_NAME) -f Containerfile.$* rpmbuild
	$(PODMAN) rm --ignore $(IMAGE_NAME)-tmp
	$(PODMAN) create --name $(IMAGE_NAME)-tmp $(IMAGE_NAME)
	mkdir $@
	$(PODMAN) cp $(IMAGE_NAME)-tmp:/rpmbuild/RPMS $@/
	$(PODMAN) cp $(IMAGE_NAME)-tmp:/rpmbuild/SRPMS $@/
	$(PODMAN) rm $(IMAGE_NAME)-tmp
	$(PODMAN) rmi --ignore $(IMAGE_NAME)

.PHONY: clean
clean:
	rm -rf *.build.bak *.build
	$(PODMAN) rmi --ignore $(IMAGE_NAME)-el8 $(IMAGE_NAME)-el9 $(IMAGE_NAME)-el10 $(IMAGE_NAME)-eln
