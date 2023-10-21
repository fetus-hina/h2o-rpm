H2O_GIT_DATE := 20231011
H2O_GIT_REF := b311c049d433a421e00bc52c442d47f373b949a1
H2O_GIT_REF_SHORT := $(shell echo "${H2O_GIT_REF:0:7}")

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

rpmbuild/SOURCES/h2o-$(H2O_GIT_REF).tar.gz:
	curl -fsSL https://github.com/h2o/h2o/archive/$(H2O_GIT_REF).tar.gz -o $@

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

.PHONY: clean
clean:
	rm -rf *.build.bak *.build tmp Dockerfile
	docker images | grep -q $(IMAGE_NAME)-el7 && docker rmi $(IMAGE_NAME)-el7 || true
	docker images | grep -q $(IMAGE_NAME)-el8 && docker rmi $(IMAGE_NAME)-el8 || true
	docker images | grep -q $(IMAGE_NAME)-el9 && docker rmi $(IMAGE_NAME)-el9 || true
