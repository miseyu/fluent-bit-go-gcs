.PHONY: release build clean test

SUDO := $(shell docker info > /dev/null 2> /dev/null || echo "sudo")

TEST_FLAGS?=

# NB default target architecture is amd64. If you would like to try the
# other one -- pass an ARCH variable, e.g.,
#  `make ARCH=arm64`
ifeq ($(ARCH),)
	ARCH=amd64
endif
CURRENT_OS_ARCH=$(shell echo `go env GOOS`-`go env GOARCH`)
GOBIN?=$(shell echo `go env GOPATH`/bin)

IMAGE_TAG:=$(shell git rev-parse HEAD)
VCS_REF:=$(shell git rev-parse HEAD)
BUILD_DATE:=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

HELM_REGISTRY_PATH="./docs/helm"
HELM_REGISTRY_URL="https://releases.universe.sh/helm/"

all: release

release:
	go build -buildmode=c-shared -o build/out_gcs.so -ldflags "-X main.version=$(shell ./container/image-tag.sh)";

clean:
	go clean
	rm -rf ./build

test:
	PATH="${PWD}/bin:${PWD}/test/bin:${PATH}" go test ${TEST_FLAGS} $(shell go list ./... | sort -u)

build:
	$(SUDO) docker build -t fluent-bit-out-gcs:$(IMAGE_TAG) \
		--build-arg VCS_REF="$(VCS_REF)" \
		--build-arg BUILD_DATE="$(BUILD_DATE)" \
		-f Dockerfile .
	touch $@

run:
	docker run -it -p 24224:24224 -v ($PWD)/credentials.json:/fluent-bit/etc/credentials.json fluent-bit-out-gcs:$(IMAGE_TAG)

helm:
	helm package helm/* --destination ${HELM_REGISTRY_PATH}
	helm repo index --url ${HELM_REGISTRY_URL} ${HELM_REGISTRY_PATH} --merge ${HELM_REGISTRY_PATH}/index.yaml
