ifndef GOPATH
$(error No GOPATH set)
endif

BIN_DIR := bin
DIST_DIR := _dist
GO_PACKAGES := log ansible
MAIN_GO := gosupervise.go
HELM_BIN := $(BIN_DIR)/gosupervise

VERSION_PREFIX := $(shell git describe --tags --abbrev=0 2>/dev/null)

ifndef VERSION_PREFIX
  VERSION_PREFIX := v0.1.0
endif

VERSION := ${VERSION_PREFIX}+$(shell git rev-parse --short HEAD)

export GO15VENDOREXPERIMENT=1

ifndef VERSION
  VERSION := git-$(shell git rev-parse --short HEAD)
endif

build: $(MAIN_GO)
	go build -o $(HELM_BIN) -ldflags "-X main.version=${VERSION}" $<

bootstrap:
	go get -u github.com/golang/lint/golint github.com/mitchellh/gox
	glide up

build-all:
	gox -verbose \
	-ldflags "-X main.version=${VERSION}" \
	-os="linux darwin " \
	-arch="amd64 386" \
	-output="$(DIST_DIR)/{{.OS}}-{{.Arch}}/{{.Dir}}" .

clean:
	rm -rf $(DIST_DIR) $(BIN_DIR)

dist: build-all
	@cd $(DIST_DIR) && \
	find * -type d -exec zip -jr gosupervise-$(VERSION)-{}.zip {} \; && \
	cd -

install: build
	install -d ${DESTDIR}/usr/local/bin/
	install -m 755 $(HELM_BIN) ${DESTDIR}/usr/local/bin/gosupervise

prep-bintray-json:
# TRAVIS_TAG is set to the tag name if the build is a tag
ifdef TRAVIS_TAG
	@jq '.version.name |= "$(VERSION)"' _scripts/ci/bintray-template.json | \
		jq '.package.repo |= "gosupervise"' > _scripts/ci/bintray-ci.json
else
	@jq '.version.name |= "$(VERSION)"' _scripts/ci/bintray-template.json \
		> _scripts/ci/bintray-ci.json
endif

quicktest:
	go test -short ./ $(addprefix ./,$(GO_PACKAGES))

test: test-style
	go test -v ./ $(addprefix ./,$(GO_PACKAGES))

test-style:
	@if [ $(shell gofmt -e -l -s *.go $(GO_PACKAGES)) ]; then \
		echo "gofmt check failed:"; gofmt -e -l -s *.go $(GO_PACKAGES); exit 1; \
	fi
	@for i in . $(GO_PACKAGES); do \
		golint $$i; \
	done
	@for i in . $(GO_PACKAGES); do \
		go vet github.com/fabric8io/gosupervise/$$i; \
	done

.PHONY: bootstrap \
				build \
				build-all \
				clean \
				dist \
				install \
				prep-bintray-json \
				quicktest \
				test \
				test-charts \
				test-style